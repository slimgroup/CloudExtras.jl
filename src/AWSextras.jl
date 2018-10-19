module AWSextras
    using AWSCore
	using AWSS3
    using Blosc
    using Printf
    using Serialization
    using ..common: file_parts

    include("AWSextras/any.jl")
    include("AWSextras/array.jl")
    include("AWSextras/model.jl")

end
