class Mean:
	var sum: float
	var count: int
	var type: Type
	var values: PackedFloat32Array
	enum Type {Mean, AbsMean, MeanSquare, RootMeanSquare, StandardDeviation}

	func _init(mean_type: Type = Type.Mean):
		type = mean_type


	func append_array(array: PackedFloat32Array):
		for value in array:
			append(value)


	func append(value: float):
		if type == Type.StandardDeviation:
			values.append(value)

		elif type in [Type.MeanSquare, Type.RootMeanSquare]:
			value *= value

		sum += value

		count += 1


	func calculate() -> float:
		var result := sum / count

		if type == Type.StandardDeviation:
			result = _std_dev(result)

		elif type == Type.RootMeanSquare:
			result = sqrt(result)

		elif type == Type.AbsMean:
			result = abs(result)

		count = 0
		sum = 0

		return result


	func _std_dev(mean: float) -> float:
		var variance: float = 0

		for i in count:
			variance += (values[i] - mean) ** 2
		var std_dev := sqrt(variance / count)

		values.clear()

		return std_dev
