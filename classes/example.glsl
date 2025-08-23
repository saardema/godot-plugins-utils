#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

#include "gravity-inc.gdshaderinc"

layout(binding = 1, rgba32f) uniform image2D treeTexture;

layout(binding = 3, set = 1, std430) restrict buffer BodiesReadBuffer {
    Body bodiesRead[];
};

layout(binding = 4, set = 1, std430) restrict buffer BodiesWriteBuffer {
    Body bodiesWrite[];
};

layout(binding = 5, std430) restrict buffer PoolBuffer {
    int pool[];
};

layout(binding = 6, std430) restrict buffer LODsBuffer {
    LOD lods[];
};

layout(binding = 7, std430) restrict buffer HeadersBuffer {
    PartitionHeader headers[];
};

layout(binding = 9, std430) restrict buffer IndexBuffer {
    uint indices[];
};

layout(binding = 10, std430) restrict buffer TreeBuffer {
    TreeNode nodes[];
};

layout(binding = 11, std430) restrict buffer StatsBuffer {
    float stats[];
};

Body body = bodiesRead[ID];
const uint maxSteps = 1 << (mapLodCount*2 + 2);
const uint respawnLimit = 100;
const ivec2 steps[4] = {ivec2(1, 0), ivec2(-1, 1), ivec2(1, 0), ivec2(1, -1)};
uint bitStepTracker = 0;
uvec2 bitCursor = uvec2(0);
uint lodIdx = 0;
LOD lod = lods[lodIdx];
TreeNode node;
vec2 globalCursor = vec2(0);

void bounceEdge() {
    if (abs(body.position.x - 0.5) > 0.5) {
        body.position.x = clamp(body.position.x, 0, 1);
        body.velocity.x = -body.velocity.x;
    }

    if (abs(body.position.y - 0.5) > 0.5) {
        body.position.y = clamp(body.position.y, 0, 1);
        body.velocity.y = -body.velocity.y;
    }
}

void teleportEdge() {
    body.position -= step(1, body.position);
    body.position += step(body.position, vec2(0));
    body.position = clamp(body.position, -1, 2);
}

void retire(uint index) {
    bodiesRead[index].radius = -1;

    atomicAdd(pool[workGroupIndex], 1);

    uint offset = workGroupSize + workGroupSize * workGroupIndex;
    pool[offset + pool[workGroupIndex]] = int(index);
}

uint reclaim() {
    if (pool[workGroupIndex] > 0) {
        // Decrement workgroup specific pointer
        atomicAdd(pool[workGroupIndex], -1);

        // Header with pointers per workgroup + invocations per workgroup
        uint offset = workGroupSize + workGroupSize * workGroupIndex;
        return min(global_size_xyz - 1, pool[offset + pool[workGroupIndex] + 1]);
    }

    return -1;
}

void respawn(uint amount, uint srcIdx) {
    float massSum = 0;
    uint respawnIndices[respawnLimit];

    for (uint i = 0; i < amount; i++) {
        uint index = reclaim();
        if (index == -1) {
            amount = i;
            break;
        }
        respawnIndices[i] = index;
        massSum += bodiesRead[index].mass;
    }

    float avgMass = massSum / amount;
    float avgRadius = pow(avgMass, 0.333);

    for (uint i = 0; i < amount; i++) {
        uint index = respawnIndices[i];
        bodiesRead[index].mass = avgMass;
        bodiesRead[index].radius = avgRadius;
        float randA = random(bodiesRead[index].position) - 0.5;
        float randB = random(bodiesRead[index].velocity) - 0.5;
        vec2 randV = normalize(vec2(randA, randB));
        bodiesRead[index].position = bodiesRead[srcIdx].position + randV * 0.003;
        bodiesRead[index].velocity = bodiesRead[index].velocity * 0.5 + bodiesRead[srcIdx].velocity * 0.4;
    }
}

void handleCollision(uint indexB) {
    float ratio = body.radius / bodiesRead[indexB].radius;
    float chanceA = random(body.position);
    float chanceB = random(body.velocity);
    uint winner;
    uint loser;

    if (ratio > 2 || chanceB > 0.5) {
        winner = ID;
        loser = indexB;
    } else {
        winner = indexB;
        loser = ID;
    }

    bodiesRead[winner].mass += bodiesRead[loser].mass;
    bodiesRead[winner].radius = pow(bodiesRead[winner].mass, 0.333);
    retire(loser);

    if (ratio < 5 && ratio > 0.2 && pool[workGroupIndex] > 10) {
        uint amount = uint(chanceA * min(respawnLimit, pool[workGroupIndex]));
        respawn(amount, loser);
    }
}

vec2 getForce(vec2 position, float mass) {
    vec2 offset = position - body.position;
    // offset -= step(0.5, abs(offset)) * sign(offset);
    offset *= params.gravity_scale;
    float distSq = dot(offset, offset) + params.gravity_threshold;
    float invDistCubed = inversesqrt(distSq * distSq * distSq);

    return mass * invDistCubed * offset;
}

vec2 getForceFromPartition() {
    vec2 force = vec2(0);
    uint partitionIdx = worldToPartitionZIndex(node.center);
    PartitionHeader header = headers[partitionIdx];

    for (uint i = header.offset; i < header.offset + header.count; i++) {
        Body body = bodiesRead[indices[i]];
        force += getForce(body.position, body.mass) * (indices[i] == ID ? 0.0 : 1.0);
    }

    return force;
}

void debugTree() {
    ivec2 iCoords = ivec2(globalCursor * lod.resolution);
    iCoords.x += lod.offset;
    float dist = dot(body.position - node.center, body.position - node.center);
    imageStore(treeTexture, iCoords, vec4(node.center, 1.0 / (1+dist*dist), 0));
}

vec2 getCursor() {
    vec2 cursor = vec2(0);
    uint mask = 1;
    uint bits = bitStepTracker;

    for (uint i = 0; i <= mapLodCount; i++) {
        cursor.x += (bits & mask) >> i;
        mask <<= 1;
        cursor.y += (bits & mask) >> i + 1;
        mask <<= 1;
    }

    cursor *= lods[0].stepSize;

    return cursor;
}

uint getNextLodIdx() {
    vec2 cursor;

    for (uint i = mapLodCount - 1; i > 0; i--) {
        cursor = globalCursor + lods[i].stepSize * 0.707;
        vec2 offset = (body.position - cursor);
        offset -= step(0.5, abs(offset)) * sign(offset);
        float dsq = dot(offset, offset);
        if (dsq > lods[i].stepSizeSq) return i;
    }

    return 0;
}

void setLod(uint idx) {
    lodIdx = idx;
    lod = lods[idx];
}

vec2 traverseMap() {
    vec2 force = vec2(0);

    for (uint i = 0; i < params.maxIterations && bitStepTracker <= maxSteps; i++) {
        uint nextLod = getNextLodIdx();
        bool subStepsIncomplete = (bitStepTracker & (1 << (nextLod * 2)) - 1) != 0;
        setLod(nextLod > lodIdx && subStepsIncomplete ? lodIdx : nextLod);

        node = nodes[worldToNodeZIndex(globalCursor, lod)];
        if (ID == 0 && (params.debugMode & DEBUG_MODE_MAP) > 0) debugTree();
        force += lodIdx == -1
            ? getForceFromPartition()
            : getForce(node.center, node.mass);

        bitStepTracker += 1 << (lodIdx * 2);
        globalCursor = getCursor();
    }

    return force;
}

vec2 traverseMapStatic() {
    vec2 force = vec2(0);
    uint nIndex = 0;
    ivec2 home;
    uint iter = 0;

    const ivec2 steps[27] = {
        ivec2(-2, -2),
        ivec2(-1, -2),
        ivec2(-2, -1),

        ivec2( 0, -2),

        ivec2( 1, -2),
        ivec2( 2, -2),
        ivec2( 2, -1),

        ivec2(-2,  0),

        ivec2(-2,  1),
        ivec2(-2,  2),
        ivec2(-1,  2),

        ivec2( 2,  0),

        ivec2( 2,  1),
        ivec2( 0,  2),
        ivec2( 1,  2),
        ivec2( 2,  2),

        ivec2( 3, -2),
        ivec2( 3, -1),
        ivec2( 3,  0),
        ivec2( 3,  1),
        ivec2( 3,  2),

        ivec2(-2,  3),
        ivec2(-1,  3),
        ivec2( 0,  3),
        ivec2( 1,  3),
        ivec2( 2,  3),
        ivec2( 3,  3),
    };

    home = ivec2(round(body.position * partitionRes)) * 2;

    for (int l = 0; l < 8; ++l) {
        home >>= 1;
        setLod(l);

        for (int s = 0; s < 27; ++s) {
            if (l == 7 && (s == 5 || s == 6 || s >= 9)) continue;

            ivec2 loc = steps[s];

            if (s >= 16) {
                if (loc.x == 3) loc.x -= (home.x&1) * 6;
                if (loc.y == 3) loc.y -= (home.y&1) * 6;
            }

            loc = (home + loc) & lod.resolution - 1;
            nIndex = interleave(loc.x, loc.y);
            node = nodes[lod.offsetSq + nIndex];
            force += getForce(node.center, node.mass);

            if (ID == 0 && (params.debugMode & DEBUG_MODE_MAP) > 0) {
                if (++iter > params.maxIterations) return force;
                globalCursor = partitionZIndexToWorld(nIndex << lodIdx * 2);
                debugTree();
                stats[0] = nIndex;
                uvec2 c = deinterleave(nIndex);
                stats[1] = c.x;
                stats[2] = c.y;
                stats[3] = home.x;
                stats[4] = home.y;
            }
        }
    }

    return force;
}

vec2 getLocalGravity() {
    vec2 force = vec2(0);
    ivec2 pos = ivec2(body.position * partitionRes + 0.5);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            uvec2 pPos = (pos + uvec2(x, y)) % partitionRes;
            uint partitionIdx = interleave(pPos.x, pPos.y);
            PartitionHeader header = headers[partitionIdx];
            uint count = min(PART_SIZE, header.count);

            for (uint i = header.offset; i < header.offset + count; i++) {
                Body body = bodiesRead[indices[i]];
                if (indices[i] != ID) force += getForce(body.position, body.mass);
            }

            if (ID == 0 && (params.debugMode & DEBUG_MODE_MAP) > 0) {
                globalCursor = partitionZIndexToWorld(partitionIdx);
                node = nodes[partitionIdx];
                debugTree();
            }
        }
    }

    return force;
}

void process() {
    body.velocity += params.gravity * body.acceleration * params.time_scale * 0.5;
    body.position += body.velocity * params.time_scale;

    body.acceleration = getForce(vec2(0.5), params.centerMass);
    body.acceleration += getLocalGravity();
    body.acceleration += traverseMapStatic();

    body.velocity += params.gravity * body.acceleration * params.time_scale * 0.5;

    body.velocity /= 1 + params.vel_damp / body.mass * params.time_scale;

    teleportEdge();
}

void main() {
    if (params.time_scale == 0 || ID == 1) return;

    process();
    bodiesWrite[ID] = body;
}