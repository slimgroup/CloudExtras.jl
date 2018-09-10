module CloudExtras

include("common.jl")
include("AWSextras.jl")
export AWSextras
include("GCPextras.jl")
export GCPextras

end # module
