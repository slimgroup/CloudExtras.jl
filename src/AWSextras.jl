module AWSextras
    using AWSCore
	using AWSS3
    using Blosc
    using ..common: file_parts

    include("AWSextras/any.jl")
    include("AWSextras/array.jl")

end
