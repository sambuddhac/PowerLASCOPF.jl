abstract type AbstractModel end
abstract type IntervalType end
abstract type GenIntervals <: IntervalType end
abstract type LineIntervals <: IntervalType end
abstract type LoadIntervals <: IntervalType end

@kwdef mutable struct ExtendedThermalGenerationCost 
    a::Float64 # Coefficient of the quadratic term
    b::Float64 # Coefficient of the linear term
    c::Float64 # Constant term
    d::Float64 # Coefficient of the cubic term
    e::Float64 # Coefficient of the quartic term
end

@kwdef mutable struct ExtendedRenewableGenerationCost 
    a::Float64 # Coefficient of the quadratic term
    b::Float64 # Coefficient of the linear term
    c::Float64 # Constant term
    d::Float64 # Coefficient of the cubic term
    e::Float64 # Coefficient of the quartic term
end

@kwdef mutable struct ExtendedHydroGenerationCost 
    a::Float64 # Coefficient of the quadratic term
    b::Float64 # Coefficient of the linear term
    c::Float64 # Constant term
    d::Float64 # Coefficient of the cubic term
    e::Float64 # Coefficient of the quartic term
end

@kwdef mutable struct ExtendedStorageGenerationCost 
    a::Float64 # Coefficient of the quadratic term
    b::Float64 # Coefficient of the linear term
    c::Float64 # Constant term
    d::Float64 # Coefficient of the cubic term
    e::Float64 # Coefficient of the quartic term
end

@kwdef mutable struct GenFirstBaseInterval <: GenIntervals
    lambda_1::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness for across the dispatch intervals
    lambda_2::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness for across the dispatch intervals
    B::Float64 # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    D::Float64 # Disagreement between the generator output values for the next interval by the present and the next interval, at the previous iteration
    BSC::Array{Float64} # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

@kwdef mutable struct GenFirstContInterval <: GenIntervals
    lambda_1::Array{Float64}, 
    lambda_2::Array{Float64}, # APP Lagrange Multiplier corresponding to the complementary slackness
    B::Array{Float64},# Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
    D::Array{Float64},# Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    BSC::Float64, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

@kwdef mutable struct GenFirstBaseIntervalDZ <: GenIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

@kwdef mutable struct GenFirstContIntervalDZ <: GenIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

@kwdef mutable struct GenLastBaseInterval <: GenIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

@kwdef mutable struct GenLastContInterval <: GenIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

@kwdef mutable struct GenInterRNDInterval <: GenIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

@kwdef mutable struct GenInterRSDInterval <: GenIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

@kwdef mutable struct LineBaseInterval <: LineIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

@kwdef mutable struct LineRNDInterval <: LineIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end