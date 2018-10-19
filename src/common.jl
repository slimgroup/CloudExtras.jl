module common

    export file_parts
    function file_parts(a::Array{DT},maxsize::Integer) where {DT<:Number}
        nfiles = ceil(Int,sizeof(a)/maxsize)
        nelmts = length(a)
        parts = Vector{Int}(undef,nfiles)
        idxs = Vector{Int}(undef,nfiles+1)
        ids = Vector{Int}(undef,nfiles)
        ide = Vector{Int}(undef,nfiles)
        r::Int = rem(nelmts,nfiles)
        c::Int = ceil(Int,nelmts/nfiles)
        f::Int = floor(Int,nelmts/nfiles)
        parts[1:r]        .= c
        parts[r+1:nfiles] .= f
        @assert sum(parts)==nelmts "FATAL ERROR: failed to properly partition $nelmts to $nfiles files"
        for i=0:nfiles idxs[i+1]=sum(parts[1:i])+1 end
        for i=1:nfiles ids[i]=idxs[i] end
        for i=1:nfiles ide[i]=idxs[i+1]-1 end
        return (nfiles,nelmts,parts,ids,ide)
    end

end
