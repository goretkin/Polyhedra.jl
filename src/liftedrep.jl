export LiftedHRepresentation, LiftedVRepresentation

# H-Represenation

# No copy since I do not modify anything and a copy is done when building a polyhedron
mutable struct LiftedHRepresentation{N, T, MT<:AbstractMatrix{T}} <: MixedHRep{N, T}
    # Ax >= 0, it is [b -A] * [z; x] where z = 1
    A::MT
    linset::BitSet

    function LiftedHRepresentation{N, T, MT}(A::MT, linset::BitSet=BitSet()) where {N, T, MT}
        if !isempty(linset) && last(linset) > size(A, 1)
            error("The elements of linset should be between 1 and the number of rows of A")
        end
        if size(A, 2) != N+1
            error("dimension does not match")
        end
        new{N, T, MT}(A, linset)
    end
end

similar_type(::Type{LiftedHRepresentation{M, S, MT}}, ::FullDim{N}, ::Type{T}) where {M, S, N, T, MT} = LiftedHRepresentation{N, T, similar_type(MT, T)}
hvectortype(p::Type{LiftedHRepresentation{N, T, MT}}) where {N, T, MT} = vectortype(MT)

LiftedHRepresentation{N, T}(A::AbstractMatrix{T}, linset::BitSet=BitSet()) where {N, T} = LiftedHRepresentation{N, T, typeof(A)}(A, linset)
LiftedHRepresentation{N, T}(A::AbstractMatrix, linset::BitSet=BitSet()) where {N, T} = LiftedHRepresentation{N, T}(AbstractMatrix{T}(A), linset)
LiftedHRepresentation(A::AbstractMatrix{T}, linset::BitSet=BitSet()) where T = LiftedHRepresentation{size(A, 2) - 1, T}(A, linset)

LiftedHRepresentation(h::HRepresentation{N, T}) where {N, T} = LiftedHRepresentation{N, T}(h)
LiftedHRepresentation{N, T}(h::HRepresentation{N}) where {N, T} = LiftedHRepresentation{N, T, hmatrixtype(typeof(h), T)}(h)

function LiftedHRepresentation{N, T, MT}(hyperplanes::ElemIt{<:HyperPlane{N, T}}, halfspaces::ElemIt{<:HalfSpace{N, T}}) where {N, T, MT}
    nhyperplane = length(hyperplanes)
    nhrep = nhyperplane + length(halfspaces)
    A = emptymatrix(MT, nhrep, N+1)
    linset = BitSet(1:nhyperplane)
    for (i, h) in enumerate(hyperplanes)
        A[i,2:end] = -h.a
        A[i,1] = h.β
    end
    for (i, h) in enumerate(halfspaces)
        A[nhyperplane+i,2:end] = -h.a
        A[nhyperplane+i,1] = h.β
    end
    LiftedHRepresentation{N, T}(A, linset)
end

Base.copy(ine::LiftedHRepresentation{N,T}) where {N,T} = LiftedHRepresentation{N,T}(copy(ine.A), copy(ine.linset))

Base.isvalid(hrep::LiftedHRepresentation{N, T}, idx::HIndex{N, T}) where {N, T} = 0 < idx.value <= size(hrep.A, 1) && (idx.value in hrep.linset) == islin(idx)
Base.done(idxs::HIndices{N, T, <:LiftedHRepresentation{N, T}}, idx::HIndex{N, T}) where {N, T} = idx.value > size(idxs.rep.A, 1)
Base.get(hrep::LiftedHRepresentation{N, T}, idx::HIndex{N, T}) where {N, T} = valuetype(idx)(-hrep.A[idx.value,2:end], hrep.A[idx.value,1])

# V-Representation

mutable struct LiftedVRepresentation{N, T, MT<:AbstractMatrix{T}} <: MixedVRep{N, T}
    R::MT # each row is a vertex if the first element is 1 and a ray otherwise
    linset::BitSet

    function LiftedVRepresentation{N, T, MT}(R::MT, linset::BitSet=BitSet([])) where {N, T, MT}
        if length(R) > 0 && size(R, 2) != N+1
            error("dimension does not match")
        end
        if !isempty(linset) && last(linset) > size(R, 1)
            error("The elements of linset should be between 1 and the number of rows of R")
        end
        new{N, T, MT}(R, linset)
    end
end

similar_type(::Type{LiftedVRepresentation{M, S, MT}}, ::FullDim{N}, ::Type{T}) where {M, S, N, T, MT} = LiftedVRepresentation{N, T, similar_type(MT, T)}
vvectortype(p::Type{LiftedVRepresentation{N, T, MT}}) where {N, T, MT} = vectortype(MT)

LiftedVRepresentation{N, T}(R::AbstractMatrix{T}, linset::BitSet=BitSet()) where {N, T} = LiftedVRepresentation{N, T, typeof(R)}(R, linset)
LiftedVRepresentation{N, T}(R::AbstractMatrix, linset::BitSet=BitSet()) where {N, T} = LiftedVRepresentation{N, T}(AbstractMatrix{T}(R), linset)
LiftedVRepresentation(R::AbstractMatrix{T}, linset::BitSet=BitSet()) where T = LiftedVRepresentation{size(R, 2) - 1, T}(R, linset)

LiftedVRepresentation(v::VRepresentation{N, T}) where {N, T} = LiftedVRepresentation{N, T}(v)
LiftedVRepresentation{N, T}(v::VRepresentation{N}) where {N, T} = LiftedVRepresentation{N, T, vmatrixtype(typeof(v), T)}(v)

debug = nothing
using Parameters
function LiftedVRepresentation{N, T, MT}(vits::VIt{N, T}...) where {N, T, MT}
    global debug
    debug = Dict{Symbol, Any}()
    @pack! debug = vits, N, T, MT
    @show vits
    @show typeof(vits)
    @show typeof(vits[1])
    points, lines_, rays = fillvits(FullDim{N}(), vits...)
    @pack! debug = lines_
    @show points lines_ rays
    npoint = length(points)
    nline = length(lines_)
    nray = length(rays)
    @pack! debug = npoint, nline, nray
    @show npoint nline nray
    nvrep = npoint + nline + nray
    R = emptymatrix(MT, nvrep, N+1)
    linset = BitSet()
    function _fill(offset, z, ps)
        @pack! debug = ps
        @show ps
        println(ps)
        @show typeof(ps)
        @show length(ps)
        @show length(enumerate(ps))
        for (i, p) in enumerate(ps)
            @show i
            @show coord(p)
            @show R[offset + i,2:end]
            R[offset + i,2:end] = coord(p)
            R[offset + i,1] = z
            if islin(p)
                push!(linset, offset + i)
            end
        end
    end
    _fill(0, one(T), points)
    println("LINES")
    @show length(lines_)
    _fill(npoint, zero(T), lines_)
    _fill(npoint+nline, zero(T), rays)
    LiftedVRepresentation{N, T}(R, linset)
end

Base.copy(ext::LiftedVRepresentation{N,T}) where {N,T} = LiftedVRepresentation{N,T}(copy(ext.R), copy(ext.linset))

nvreps(ext::LiftedVRepresentation) = size(ext.R, 1)

function isrowpoint(ext::LiftedVRepresentation{N,T}, i) where {N,T}
    ispoint = ext.R[i,1]
    @assert ispoint == zero(T) || ispoint == one(T)
    ispoint == one(T)
end

function Base.isvalid(vrep::LiftedVRepresentation{N, T}, idx::VIndex{N, T}) where {N, T}
    isp = isrowpoint(vrep, idx.value)
    isl = (idx.value in vrep.linset)
    @assert !isp || !isl # if isp && isl, it is a symmetric point but it is not allowed to mix symmetric points and points
    0 < idx.value <= nvreps(vrep) && isp == ispoint(idx) && isl == islin(idx)
end
Base.done(idxs::VIndices{N, T, <:LiftedVRepresentation{N, T}}, idx::VIndex{N, T}) where {N, T} = idx.value > size(idxs.rep.R, 1)
Base.get(vrep::LiftedVRepresentation{N, T}, idx::VIndex{N, T}) where {N, T} = valuetype(idx)(vrep.R[idx.value,2:end])
