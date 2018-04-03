    export array_put
    """

        julia> array_put(aws,bucket,path,array;[level])

    Stores an array to AWS S3 bucket.

    # Signature

        function array_put{DT<:Number}(aws::AWSCore.AWSConfig,
            bucket::String,path::String,array::DenseArray{DT};
            level::Int=1,max_size::Int=2000)

    # Arguments

    - `aws`: aws config created by AWSCore.aws_config
    - `bucket`: name of AWS S3 bucket
    - `path`: file key/path name
    - `array`: dense numeric array
    - `level`: Blosc compression level (0-9); 1 is typically OK, anything above 5 is typically an over-kill
    - `max_size`: maximum array size (MB<=2000) before going into multi-part mode

    # Examples

    - `array_put(aws,"slimbucket","tmp/test/small",a)`: put array `a` into bucket `slimbucket` under path `tmp/test/small`

    # Notes:

    - use `array_delete` to delete object created with `array_put`

    """
    function array_put{DT<:Number}(aws::AWSCore.AWSConfig,bucket::String,path::String,a::DenseArray{DT};level::Int=1,max_size::Int=2000)
        max_size > 2000 && warn("AWSS3/array_put: given max_size > 2000; using default 2000")
        cmp_max=min(2000*1024^2,max_size*1024^2) #blosc compression max 2147483631 bytes < (2*1024^3)
        if sizeof(a)<cmp_max # single file
            szs=size(a)
            dims=length(szs)
            tags=Dict("creator"=>"SO-SLIM","type"=>"Array")
                tags["eltype"]="$(eltype(a))"
                tags["dims"]="$(dims)"
                for i=1:dims tags["n$i"]="$(szs[i])"; end
            ac=Blosc.compress(vec(a);level=level);
	        s3_put(aws, bucket, path, ac, tags=tags);
            return nothing
        else # multi-part files
            #warn("AWSS3/array_put: large array - going into multi-part mode";key="AWS S3 array_put",once=true)
            szs=size(a)
            dims=length(szs)
            (nfiles,nelmts,parts,idxs,idxe)=file_parts(a,cmp_max)
                tags=Dict("creator"=>"SO-SLIM","type"=>"metaArray")
                tags["nfiles"]="$(nfiles)"
                tags["nelmts"]="$(nelmts)"
                tags["eltype"]="$(eltype(a))"
                tags["dims"]="$(dims)"
                for i=1:dims tags["n$i"]="$(szs[i])"; end
            #println((nfiles,nelmts,parts,idxs,idxe))
            #for i=1:nfiles println((i,parts[i],idxs[i],idxe[i])) end
            av=vec(a)
            for i=1:nfiles
                ppath=@sprintf("%s-parts/%6.6d",path,i)
                #println(ppath)
                pc=Blosc.compress(av[idxs[i]:idxe[i]];level=level);
                s3_put(aws, bucket, ppath, pc);
            end
            d=[parts idxs idxe]
            dc=Blosc.compress(vec(d);level=level);
            s3_put(aws, bucket, path, dc, tags=tags);
            return nothing
        end
    end

    export array_get
    """

        julia> array_get(aws,bucket,path)

    Reads from AWS S3 bucket an array stored by `array_put`.

    # Signature

        function array_get(aws::AWSCore.AWSConfig,
            bucket::String,path::String)

    # Arguments

    - `aws`: aws config created by AWSCore.aws_config
    - `bucket`: name of AWS S3 bucket
    - `path`: file key/path name

    # Examples

    - `A=array_get(aws,"slimbucket","tmp/test/small")`: gets array `a` from bucket `slimbucket` and path `tmp/test/small`

    # Notes:

    - use `array_delete` to delete object created with `array_put`

    """
    function array_get(aws::AWSCore.AWSConfig,bucket::String,path::String)
        s3_exists(aws, bucket, path) || error("AWSS3/array_get: file $path does not exist in $bucket.")
        tags=s3_get_tags(aws, bucket, path);
        (haskey(tags,"creator")&&tags["creator"]=="SO-SLIM") || error("AWSS3/array_get: file $path in $bucket is unknown.")
        haskey(tags,"type") || error("AWSS3/array_get: file $path in $bucket does not have known type.")
        if tags["type"]=="Array" # single file
            eval(parse("edt=$(tags["eltype"])"))
            eval(parse("dims=$(tags["dims"])"))
            szs=Vector{Int}(dims)
            for i=1:dims n=tags["n$i"]; szs[i]=parse(n); end
	        ac=s3_get(aws, bucket, path);
	        a=reshape(Blosc.decompress(edt,ac),(szs...));
            return a
        elseif tags["type"]=="metaArray" # multi-part files
            eval(parse("nfiles=$(tags["nfiles"])"))
            eval(parse("nelmts=$(tags["nelmts"])"))
            eval(parse("edt=$(tags["eltype"])"))
            eval(parse("dims=$(tags["dims"])"))
            szs=Vector{Int}(dims)
            for i=1:dims n=tags["n$i"]; szs[i]=parse(n); end
            dc=s3_get(aws, bucket, path);
            d=reshape(Blosc.decompress(Int,dc),(nfiles,3));
            parts=d[:,1]; idxs=d[:,2]; idxe=d[:,3];
            #println((nfiles,nelmts,parts,idxs,idxe))
            #for i=1:nfiles println((i,parts[i],idxs[i],idxe[i])) end
            av=Vector{edt}(nelmts)
            for i=1:nfiles
                ppath=@sprintf("%s-parts/%6.6d",path,i)
                #println(ppath)
                pc=s3_get(aws, bucket, ppath);
                av[idxs[i]:idxe[i]]=Blosc.decompress(edt,pc)
            end
            a=reshape(av,(szs...))
            return a
        else
            error("AWSS3/array_get: file $path in $bucket is not an array stored with array_put.")
        end
    end

    export array_delete
    """

        julia> array_delete(aws,bucket,path)

    Deletes from AWS S3 bucket an array stored by `array_put`.

    # Signature

        function array_delete(aws::AWSCore.AWSConfig,
            bucket::String,path::String)

    # Arguments

    - `aws`: aws config created by AWSCore.aws_config
    - `bucket`: name of AWS S3 bucket
    - `path`: file key/path name

    # Examples

    - `array_delete(aws,"slimbucket","tmp/test/small")`: deletes array stored by `array_put` as `tmp/test/small` and bucket `slimbucket`

    """
    function array_delete(aws::AWSCore.AWSConfig,bucket::String,path::String)
        s3_exists(aws, bucket, path) || error("AWSS3/array_delete: file $path does not exist in $bucket.")
        tags=s3_get_tags(aws, bucket, path);
        (haskey(tags,"creator")&&tags["creator"]=="SO-SLIM") || error("AWSS3/array_delete: file $path in $bucket is unknown.")
        haskey(tags,"type") || error("AWSS3/array_delete: file $path in $bucket does not have known type.")
        if tags["type"]=="Array" # single file
            s3_delete(aws,bucket,path)
        elseif tags["type"]=="metaArray" # multi-part files
            eval(parse("nfiles=$(tags["nfiles"])"))
            for i=1:nfiles
                ppath=@sprintf("%s-parts/%6.6d",path,i)
                s3_delete(aws,bucket,ppath)
            end
            s3_delete(aws,bucket,path)
        else
            error("AWSS3/array_delete: file $path in $bucket is not an array.")
        end
        return nothing
    end

