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


## Current functionality

1. putting/getting dense numerical numerical arrays for AWS S3 in module `CloudExtras.AWSextras`

	- `array_put{DT<:Number}(aws::AWSCore.AWSConfig, bucket::String, path::String, a::DenseArray{DT}; level::Int=1)`
	- `array_get(aws::AWSCore.AWSConfig, bucket::String, path::String)`
	- `array_delete(aws::AWSCore.AWSConfig, bucket::String, path::String)`

	where
	
	- `aws` is output from `AWSCore.aws_config`
	- `bucket` is AWS S3 bucket name
	- `path` is AWS S3 file key/path
	- `level` is compression level (0-9); 1 is typically good enough while anything above 5 is hardly ever usefull and computationally taxing

	Note! Arrays with sizes above 2GB will be splitted into multiple, roughly same-size, files to reduce memory overhead while writing and reading arrays.

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
