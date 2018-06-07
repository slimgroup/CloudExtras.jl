    export model_put
    """

        julia> model_put(aws,bucket,path,model_array,origins,deltas;[level])

    Stores a model array to AWS S3 bucket.

    # Signature

        function model_put{AT<:Number,OT<:Number,DT<:Number}(aws::AWSCore.AWSConfig,bucket::String,path::String,
            a::DenseArray{AT},origins::Vector{OT},deltas::Vector{DT};
            level::Int=1,max_size::Int=2000)

    # Arguments

    - `aws`: aws config created by AWSCore.aws_config
    - `bucket`: name of AWS S3 bucket
    - `path`: file key/path name
    - `model_array`: dense numeric array
    - `level`: Blosc compression level (0-9); 1 is typically OK, anything above 5 is typically an over-kill
    - `max_size`: maximum array size (MB<=2000) before going into multi-part mode

    # Examples

    - `model_put(aws,"slimbucket","tmp/test/small",a)`: put model `a` into bucket `slimbucket` under path `tmp/test/small`

    # Notes:

    - use `model_delete` to delete object created with `model_put`

    """
    function model_put{AT<:Number,OT<:Number,DT<:Number}(aws::AWSCore.AWSConfig,bucket::String,path::String,
            a::DenseArray{AT},os::Vector{OT},ds::Vector{DT};
            level::Int=1,max_size::Int=2000)
        max_size > 2000 && warn("AWSS3/model_put: given max_size > 2000; using default 2000")
        cmp_max=min(2000*1024^2,max_size*1024^2) #blosc compression max 2147483631 bytes < (2*1024^3)
        szs=size(a)
        dims=length(szs)
        if sizeof(a)<cmp_max # single file
            tags=Dict("creator"=>"SO-SLIM","type"=>"Model")
                tags["eltype"]="$(AT)"
                tags["dims"]="$(dims)"
                tags["ns"]=join(map(i->(@sprintf "%d" szs[i]),1:dims),":")
                tags["os"]=join(map(i->(@sprintf "%f" os[i]),1:dims),":")
                tags["ds"]=join(map(i->(@sprintf "%f" ds[i]),1:dims),":")
            ac=Blosc.compress(vec(a);level=level);
            s3_put(aws, bucket, path, ac, tags=tags);
            return nothing
        else # multi-part files
            #warn("AWSS3/model_put: large array - going into multi-part mode";key="AWS S3 model_put",once=true)
            (nfiles,nelmts,parts,idxs,idxe)=file_parts(a,cmp_max)
                tags=Dict("creator"=>"SO-SLIM","type"=>"metaModel")
                tags["nfiles"]="$(nfiles)"
                tags["nelmts"]="$(nelmts)"
                tags["eltype"]="$(AT)"
                tags["dims"]="$(dims)"
                tags["ns"]=join(map(i->(@sprintf "%d" szs[i]),1:dims),":")
                tags["os"]=join(map(i->(@sprintf "%f" os[i]),1:dims),":")
                tags["ds"]=join(map(i->(@sprintf "%f" ds[i]),1:dims),":")
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

    export model_get
    """

        julia> model_get(aws,bucket,path;delete=false)

    Reads from AWS S3 bucket a model array stored by `model_put`.

    # Signature

        function model_get(aws::AWSCore.AWSConfig,
            bucket::String,path::String;delete::Bool=false)

    # Arguments

    - `aws`: aws config created by AWSCore.aws_config
    - `bucket`: name of AWS S3 bucket
    - `path`: file key/path name
    - `delete`: delete file key/path after reading

    # Examples

    - `(A,o,d)=model_get(aws,"slimbucket","tmp/test/small")`: gets model_array `a`, origins `o`, and deltas `d` from bucket `slimbucket` and path `tmp/test/small`

    # Notes:

    - use `model_delete` to delete object created with `model_put`

    """
    function model_get(aws::AWSCore.AWSConfig,bucket::String,path::String;delete::Bool=false)
        s3_exists(aws, bucket, path) || error("AWSS3/model_get: file $path does not exist in $bucket.")
        tags=s3_get_tags(aws, bucket, path);
        (haskey(tags,"creator")&&tags["creator"]=="SO-SLIM") || error("AWSS3/model_get: file $path in $bucket is unknown.")
        haskey(tags,"type") || error("AWSS3/model_get: file $path in $bucket does not have known type.")
        if tags["type"]=="Model" # single file
            eval(parse("edt=$(tags["eltype"])"))
            eval(parse("dims=$(tags["dims"])"))
            szs=parse.(Int,split(tags["ns"],":"))
            os=parse.(Float64,split(tags["os"],":"))
            ds=parse.(Float64,split(tags["ds"],":"))
            ac=s3_get(aws, bucket, path);
            a=reshape(Blosc.decompress(edt,ac),(szs...));
            delete && model_delete(aws, bucket, path);
            return a,os,ds
        elseif tags["type"]=="metaModel" # multi-part files
            eval(parse("nfiles=$(tags["nfiles"])"))
            eval(parse("nelmts=$(tags["nelmts"])"))
            eval(parse("edt=$(tags["eltype"])"))
            eval(parse("dims=$(tags["dims"])"))
            szs=parse.(Int,split(tags["ns"],":"))
            os=parse.(Float64,split(tags["os"],":"))
            ds=parse.(Float64,split(tags["ds"],":"))
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
            delete && model_delete(aws, bucket, path);
            return a,os,ds
        else
            error("AWSS3/model_get: file $path in $bucket is not an model stored with model_put.")
        end
    end

    export model_delete
    """

        julia> model_delete(aws,bucket,path)

    Deletes from AWS S3 bucket a model array stored by `model_put`.

    # Signature

        function model_delete(aws::AWSCore.AWSConfig,
            bucket::String,path::String)

    # Arguments

    - `aws`: aws config created by AWSCore.aws_config
    - `bucket`: name of AWS S3 bucket
    - `path`: file key/path name

    # Examples

    - `model_delete(aws,"slimbucket","tmp/test/small")`: deletes model_array stored by `model_put` as `tmp/test/small` and bucket `slimbucket`

    """
    function model_delete(aws::AWSCore.AWSConfig,bucket::String,path::String)

        s3_exists(aws, bucket, path) || error("AWSS3/model_delete: file $path does not exist in $bucket.")
        tags=s3_get_tags(aws, bucket, path);
        (haskey(tags,"creator")&&tags["creator"]=="SO-SLIM") || error("AWSS3/model_delete: file $path in $bucket is unknown.")
        haskey(tags,"type") || error("AWSS3/model_delete: file $path in $bucket does not have known type.")
        if tags["type"]=="Model" # single file
            s3_delete(aws,bucket,path)
        elseif tags["type"]=="metaModel" # multi-part files
            eval(parse("nfiles=$(tags["nfiles"])"))
            for i=1:nfiles
                ppath=@sprintf("%s-parts/%6.6d",path,i)
                s3_delete(aws,bucket,ppath)
            end
            s3_delete(aws,bucket,path)
        else
            error("AWSS3/model_delete: file $path in $bucket is not an array.")
        end
        return nothing
    end

