module AWSextras
    using AWSCore
	using AWSS3
    using Blosc
    using ..common

    export array_put
    function array_put{DT<:Number}(aws::AWSCore.AWSConfig,bucket::String,path::String,a::Array{DT};level::Int=1)
        cmp_max=(2*1020^3) #blosc compression max 2147483631 bytes < (2*1024^3)
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
            #warn("S3 array_put: large file - going into multi-part mode";key="array_put",once=true)
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
            error("AWSS3/array_get: file $path in $bucket is not an array.")
        end
    end

    export array_delete
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

end
