    export any_put
    """

        julia> any_put(aws,bucket,path,array;[level])

    Stores any object with sizeof smaller then 5GB to AWS S3 bucket.

    # Signature

        function any_put(aws::AWSCore.AWSConfig,
            bucket::String,path::String,obj)

    # Arguments

    - `aws`: aws config created by AWSCore.aws_config
    - `bucket`: name of AWS S3 bucket
    - `path`: file key/path name
    - `obj`: Any Julia object

    # Examples

    - `any_put(aws,"slimbucket","tmp/test/Any",obj)`: put Julia object `obj` into bucket `slimbucket` under path `tmp/test/Any`

    # Notes:

    - the object is stored in the bucket in serialized form
    - use `any_delete` to delete object created with `any_put`

    """
    function any_put(aws::AWSCore.AWSConfig,bucket::String,path::String,obj)
        size_max=min(5*1024^3) #single upload size < 5GB
        sizeof(obj)<size_max || error("AWSS3/any_put: object too large for storing in AWS S3 bucket")
        tags=Dict("creator"=>"SO-SLIM","type"=>"SerilizedObject")
        buf=IOBuffer()
        serialize(buf,obj)
        objs=take!(buf)
	    s3_put(aws, bucket, path, objs, tags=tags);
        return nothing
    end

    export any_get
    """

        julia> any_get(aws,bucket,path)

    Reads from AWS S3 bucket an object stored by `any_put`.

    # Signature

        function any_get(aws::AWSCore.AWSConfig,
            bucket::String,path::String)

    # Arguments

    - `aws`: aws config created by AWSCore.aws_config
    - `bucket`: name of AWS S3 bucket
    - `path`: file key/path name

    # Examples

    - `O=any_get(aws,"slimbucket","tmp/test/Any")`: gets object `O` from bucket `slimbucket` and path `tmp/test/Any`

    # Notes:

    - the returned object is deserialized from the data stored in the bucket
    - use `any_delete` to delete object created with `any_put`

    """
    function any_get(aws::AWSCore.AWSConfig,bucket::String,path::String)
        s3_exists(aws, bucket, path) || error("AWSS3/any_get: file $path does not exist in $bucket.")
        tags=s3_get_tags(aws, bucket, path);
        (haskey(tags,"creator")&&tags["creator"]=="SO-SLIM") || error("AWSS3/any_get: file $path in $bucket is unknown.")
        (haskey(tags,"type")&&tags["type"]=="SerilizedObject") || error("AWSS3/any_get: file $path in $bucket does not have known type.")
        objs=s3_get(aws, bucket, path);
        buf=IOBuffer(objs)
        obj=deserialize(buf)
        return obj
    end

    export any_delete
    """

        julia> any_delete(aws,bucket,path)

    Deletes from AWS S3 bucket an object stored by `any_put`.

    # Signature

        function any_delete(aws::AWSCore.AWSConfig,
            bucket::String,path::String)

    # Arguments

    - `aws`: aws config created by AWSCore.aws_config
    - `bucket`: name of AWS S3 bucket
    - `path`: file key/path name

    # Examples

    - `A=any_delete(aws,"slimbucket","tmp/test/Any")`: deletes array `a` from bucket `slimbucket` and path `tmp/test/Any`

    """
    function any_delete(aws::AWSCore.AWSConfig,bucket::String,path::String)
        s3_exists(aws, bucket, path) || error("AWSS3/any_get: file $path does not exist in $bucket.")
        tags=s3_get_tags(aws, bucket, path);
        (haskey(tags,"creator")&&tags["creator"]=="SO-SLIM") || error("AWSS3/any_get: file $path in $bucket is unknown.")
        (haskey(tags,"type")&&tags["type"]=="SerilizedObject") || error("AWSS3/any_get: file $path in $bucket does not have known type.")
        s3_delete(aws, bucket, path);
        return nothing
    end

