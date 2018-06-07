# CloudExtras

Extra utilites for working with the Cloud platforms

## INSTALLATION

From julia prompt run the following if you will not need developer's write access or if you do not have GitHub account:

```
Pkg.clone("https://github.com/slimgroup/CloudExtras.jl.git")
```

or with GitHub account (and SSH keys registered) for full developer access:

```
Pkg.clone("git@github.com:slimgroup/CloudExtras.jl.git")
```

Configure AWS credentials if not done already or if needed. (On EC2 instances/containers use appropriate S3 role for EC2 if configured, otherwise run this configuration.) Use your AWS access keys and configure with command :

```
aws configure
```


## Current functionality

1. putting/getting dense numerical numerical arrays for AWS S3 in module `CloudExtras.AWSextras`

	- `array_put(aws::AWSCore.AWSConfig, bucket::String, path::String, a::DenseArray{Number}; level::Int=1,max_size::Int=2000)`
	- `A = array_get(aws::AWSCore.AWSConfig, bucket::String, path::String; delete::Bool=false)`
	- `array_delete(aws::AWSCore.AWSConfig, bucket::String, path::String)`

	where
	
	- `aws` is output from `AWSCore.aws_config`
	- `bucket` is AWS S3 bucket's name
	- `path` is AWS S3 file key/path
	- `a` is dense array of numbers
	- `delete` flag to delete file after reading
	- `level` is compression level (0-9); 1 is typically good enough while anything above 5 is hardly ever usefull and computationally taxing
	- `max_size`: maximum array size (MB<=2000) before going into multi-part mode

	Note! Arrays with sizes above 2000MB will be splitted into multiple, roughly same-size, files to reduce memory overhead while writing and reading arrays.

1. putting/getting model arrays for AWS S3 in module `CloudExtras.AWSextras` - exactly like array_put/_get/_delete but with extra arguments for origins and deltas

	- `model_put(aws::AWSCore.AWSConfig, bucket::String, path::String, a::DenseArray{Number}, o::Vector{Number}, d::Vector{Number}; level::Int=1,max_size::Int=2000)`
	- `(M, o, d) = model_get(aws::AWSCore.AWSConfig, bucket::String, path::String; delete::Bool=false)`
	- `model_delete(aws::AWSCore.AWSConfig, bucket::String, path::String)`

	where
	
	- `o` is vector of origins
	- `d` is vector of deltas

1. putting/getting Any object for AWS S3 in module `CloudExtras.AWSextras`

	- `any_put(aws::AWSCore.AWSConfig, bucket::String, path::String, obj)`
	- `any_get(aws::AWSCore.AWSConfig, bucket::String, path::String; delete::Bool=false)`
	- `any_delete(aws::AWSCore.AWSConfig, bucket::String, path::String)`

	where
	
	- `aws` is output from `AWSCore.aws_config`
	- `bucket` is AWS S3 bucket's name
	- `path` is AWS S3 file key/path
	- `obj` is Julia object of any type
	- `delete` flag to delete file after reading

	Note! Objects cannot be bigger then 5GB in serialized form.

2. to be continued


## Using With Multiple Clouds ##

Not needed yet, but the difference is in loading and calling functions. This may lead to name conflicts when different Cloud providers are mixed in the same code:

	using CloudExtras.AWSextras
	array_put(...)

while this is safe when using multiple providers in the same code:

	using CloudExtras
	AWSextras.array_put(...)


## Examples ##

Check [here](examples/)
