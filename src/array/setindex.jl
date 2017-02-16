
export setindex

immutable SetIndex{T,N} <: LazyArray{T,N}
    input::LazyArray{T,N}
    idx::Tuple
    val
end

function setindex(x::LazyArray, val, idxs...)
    SetIndex(x, idxs, val)
end

function stage(ctx, sidx::SetIndex)
    inp = cached_stage(ctx, sidx.input)

    dmn = domain(inp)
    idxs = [if isa(sidx.idx[i], Colon)
        indexes(dmn)[i]
    else
        sidx.idx[i]
    end for i in 1:length(sidx.idx)]

    ps = Array{Any}(size(chunks(inp)))
    ps[:] = chunks(inp)
    subdmns = chunks(domain(inp))
    d = ArrayDomain(idxs)

    groups = map(group_indices, subdmns.cumlength, indexes(d))
    sz = map(length, groups)
    pieces = Array(AbstractChunk, sz)
    for i = CartesianRange(sz)
        idx_and_dmn = map(getindex, groups, i.I)
        idx = map(x->x[1], idx_and_dmn)
        local_dmn = ArrayDomain(map(x->x[2], idx_and_dmn))
        s = subdmns[idx...]
        part_to_set = sidx.val
        ps[idx...] = Thunk((ps[idx...],)) do p
            q = copy(p)
            q[indexes(project(s, local_dmn))...] = part_to_set
            q
        end
    end
    inp.chunks = ps
    inp
end
