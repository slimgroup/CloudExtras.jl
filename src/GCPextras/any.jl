    export any_put
    """

        julia> any_put(gcp,bucket,path,obj)

    Stores any object with sizeof smaller then 5GB to AWS S3 bucket.

    # Signature

        function any_put(gcp::GoogleCloud.credentials.JSONCredentials,
            bucket::String,path::String,obj)

    # Arguments

    - `gcp`: gcp config created by GoogleCloud.JSONCredentials
    - `bucket`: name of AWS S3 bucket
    - `path`: file key/path name
    - `obj`: Any Julia object

    # Examples

    - `any_put(gcp,"slimbucket","tmp/test/Any",obj)`: put Julia object `obj` into bucket `slimbucket` under path `tmp/test/Any`

    # Notes:

    - the object is stored in the bucket in serialized form
    - use `any_delete` to delete object created with `any_put`

    """
    function any_put(gcp::GoogleCloud.credentials.JSONCredentials,bucket::String,path::String,obj)
        buf=IOBuffer()
        serialize(buf,obj)
        objs=take!(buf)
        session=GoogleSession(gcp, ["devstorage.full_control"])
        set_session!(GoogleCloud.storage, session)
        storage(:Object, :insert, bucket; name=path, data=objs, content_type="octet/stream")
        #s3_put(gcp, bucket, path, objs, tags=tags);
        return nothing
    end

    export any_get
    """

        julia> any_get(gcp,bucket,path;delete=false)

    Reads from AWS S3 bucket an object stored by `any_put`.

    # Signature

        function any_get(gcp::GoogleCloud.credentials.JSONCredentials,
            bucket::String,path::String;delete::Bool=false)

    # Arguments

    - `gcp`: gcp config created by GoogleCloud.JSONCredentials
    - `bucket`: name of AWS S3 bucket
    - `path`: file key/path name
    - `delete`: delete file key/path after reading

    # Examples

    - `O=any_get(gcp,"slimbucket","tmp/test/Any")`: gets object `O` from bucket `slimbucket` and path `tmp/test/Any`

    # Notes:

    - the returned object is deserialized from the data stored in the bucket
    - use `any_delete` to delete object created with `any_put`

    """
    function any_get(gcp::GoogleCloud.credentials.JSONCredentials,bucket::String,path::String;delete::Bool=false)
        session=GoogleSession(gcp, ["devstorage.full_control"])
        set_session!(GoogleCloud.storage, session)
        objs=storage(:Object, :get, bucket, path);
        #objs=s3_get(gcp, bucket, path);
        buf=IOBuffer(objs)
        obj=deserialize(buf)
        delete && any_delete(gcp, bucket, path);
        return obj
    end

    export any_delete
    """

        julia> any_delete(gcp,bucket,path)

    Deletes from AWS S3 bucket an object stored by `any_put`.

    # Signature

        function any_delete(gcp::GoogleCloud.credentials.JSONCredentials,
            bucket::String,path::String)

    # Arguments

    - `gcp`: gcp config created by GoogleCloud.JSONCredentials
    - `bucket`: name of AWS S3 bucket
    - `path`: file key/path name

    # Examples

    - `any_delete(gcp,"slimbucket","tmp/test/Any")`: deletes object stored by `any_put` as `tmp/test/Any` and bucket `slimbucket`

    """
    function any_delete(gcp::GoogleCloud.credentials.JSONCredentials,bucket::String,path::String)
        session=GoogleSession(gcp, ["devstorage.full_control"])
        set_session!(GoogleCloud.storage, session)
        objs=storage(:Object, :delete, bucket, path);
        #s3_delete(gcp, bucket, path);
        return nothing
    end

