export AbstractPolyhedraModel

abstract type AbstractPolyhedraModel <: MPB.AbstractLinearQuadraticModel end

# see the cheat in lpqp_to_polyhedra
#function PolyhedraModel(solver::MPB.AbstractMathProgSolver)
#  error("PolyhedraModel not implemented for solver $solver")
#end

#creates ambiguity with (::SimpleVRepMode, ::Vrep) when a polyhedron is given
#loadproblem!(m::AbstractPolyhedraModel, hrep::HRep, c, sense) = error("loadproblem! not implemented")

struct LinprogSolution
    status
    objval
    sol
    attrs
end

"""
    linprog(c::AbstractVector, p::Rep, solver::MathProgBase.AbstractMathProgSolver=Polyhedra.solver(p))

Solve the minimization of the objective ``\\langle c, x \\rangle`` over the polyhedron `p`.
"""
function MPB.linprog(c::AbstractVector, p::Rep{N}, solver::MPB.AbstractMathProgSolver=Polyhedra.solver(p)) where N
    m = PolyhedraModel(solver)
    if N != length(c)
        throw(DimensionMismatch("length of objective does not match dimension of polyhedron"))
    end
    MPBSI.loadproblem!(m, p, c, :Min)
    MPBSI.optimize!(m)
    stat = MPBSI.status(m)
    if stat == :Optimal
        return LinprogSolution(stat, MPBSI.getobjval(m), MPBSI.getsolution(m), Dict())
    elseif stat == :Unbounded
        attrs = Dict()
        try
            attrs[:unboundedray] = MPBSI.getunboundedray(m)
        catch
            warn("Problem is unbounded, but unbounded ray is unavailable; check that the proper solver options are set.")
        end
        return LinprogSolution(stat, nothing, [], attrs)
    else
        return LinprogSolution(stat, nothing, [], Dict())
    end
end

"""
    isempty(p::Rep, solver::MathProgBase.AbstractMathProgSolver=Polyhedra.solver(p))

Check whether the polyhedron `p` is empty by using the solver `solver`.
"""
function Base.isempty(p::Rep{N, T}, solver::MPB.AbstractMathProgSolver=Polyhedra.solver(p)) where {N, T}
    MPB.linprog(zeros(T, N), p, solver).status == :Infeasible
end
