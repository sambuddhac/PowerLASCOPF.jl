"""
OptimizerFactory for PowerLASCOPF.jl

This module provides optimizer factory functionality similar to earlier versions
of PowerSimulations.jl, adapted for PowerLASCOPF's specific needs.
"""

using JuMP
using MathOptInterface
using HiGHS
using Ipopt
using Gurobi
const MOI = MathOptInterface

# Abstract type for optimizer factories
abstract type AbstractOptimizerFactory end

"""
    OptimizerFactory

A factory for creating JuMP optimizers with specific settings.
Compatible with PowerLASCOPF solver requirements.
"""
struct OptimizerFactory <: AbstractOptimizerFactory
    optimizer_type::Type
    attributes::Dict{String, Any}
    
    function OptimizerFactory(optimizer_type::Type; attributes = Dict{String, Any}())
        return new(optimizer_type, attributes)
    end
end

"""
    OptimizerFactory(optimizer_constructor::Function; attributes = Dict{String, Any}())

Create an OptimizerFactory from a function that constructs the optimizer.
"""
function OptimizerFactory(optimizer_constructor::Function; attributes = Dict{String, Any}())
    # For function-based constructors, we'll store them differently
    return FunctionOptimizerFactory(optimizer_constructor, attributes)
end

"""
    FunctionOptimizerFactory

OptimizerFactory that uses a function to create optimizers.
"""
struct FunctionOptimizerFactory <: AbstractOptimizerFactory
    constructor::Function
    attributes::Dict{String, Any}
    
    function FunctionOptimizerFactory(constructor::Function, attributes::Dict{String, Any})
        return new(constructor, attributes)
    end
end

"""
    create_optimizer(factory::OptimizerFactory)

Create an optimizer instance from the factory.
"""
function create_optimizer(factory::OptimizerFactory)
    optimizer = factory.optimizer_type()
    
    # Set attributes if any
    for (key, value) in factory.attributes
        try
            MOI.set(optimizer, MOI.RawOptimizerAttribute(key), value)
        catch e
            @warn "Failed to set optimizer attribute $key: $e"
        end
    end
    
    return optimizer
end

function create_optimizer(factory::FunctionOptimizerFactory)
    optimizer = factory.constructor()
    
    # Set attributes if any
    for (key, value) in factory.attributes
        try
            MOI.set(optimizer, MOI.RawOptimizerAttribute(key), value)
        catch e
            @warn "Failed to set optimizer attribute $key: $e"
        end
    end
    
    return optimizer
end

"""
    set_optimizer!(model::JuMP.Model, factory::AbstractOptimizerFactory)

Set the optimizer for a JuMP model using the factory.
"""
function set_optimizer!(model::JuMP.Model, factory::AbstractOptimizerFactory)
    optimizer = create_optimizer(factory)
    JuMP.set_optimizer(model, optimizer)
    return model
end

# Convenience constructors for common optimizers
"""
    ipopt_optimizer_factory(; attributes...)

Create an OptimizerFactory for Ipopt with common PowerLASCOPF settings.
"""
function ipopt_optimizer_factory(; print_level = 0, sb = "yes", max_iter = 3000, attributes...)
    try
        default_attrs = Dict{String, Any}(
            "print_level" => print_level,
            "sb" => sb,
            "max_iter" => max_iter
        )
        
        # Merge user attributes
        for (k, v) in attributes
            default_attrs[string(k)] = v
        end
        
        return OptimizerFactory(Ipopt.Optimizer; attributes = default_attrs)
    catch e
        error("Ipopt not available. Install with: using Pkg; Pkg.add(\"Ipopt\")")
    end
end

"""
    highs_optimizer_factory(; attributes...)

Create an OptimizerFactory for HiGHS with common PowerLASCOPF settings.
"""
function highs_optimizer_factory(; time_limit = 300.0, presolve = "on", attributes...)
    try
        default_attrs = Dict{String, Any}(
            "time_limit" => time_limit,
            "presolve" => presolve
        )
        
        # Merge user attributes
        for (k, v) in attributes
            default_attrs[string(k)] = v
        end
        
        return OptimizerFactory(HiGHS.Optimizer; attributes = default_attrs)
    catch e
        error("HiGHS not available. Install with: using Pkg; Pkg.add(\"HiGHS\")")
    end
end

"""
    gurobi_optimizer_factory(; attributes...)

Create an OptimizerFactory for Gurobi with common PowerLASCOPF settings.
"""
function gurobi_optimizer_factory(; TimeLimit = 300.0, OutputFlag = 0, attributes...)
    try
        default_attrs = Dict{String, Any}(
            "TimeLimit" => TimeLimit,
            "OutputFlag" => OutputFlag
        )
        
        # Merge user attributes
        for (k, v) in attributes
            default_attrs[string(k)] = v
        end
        
        return OptimizerFactory(Gurobi.Optimizer; attributes = default_attrs)
    catch e
        error("Gurobi not available. Install with: using Pkg; Pkg.add(\"Gurobi\")")
    end
end

"""
    get_optimizer_attributes(factory::AbstractOptimizerFactory)

Get the attributes dictionary from an optimizer factory.
"""
get_optimizer_attributes(factory::AbstractOptimizerFactory) = factory.attributes

"""
    set_optimizer_attribute!(factory::AbstractOptimizerFactory, key::String, value)

Set an optimizer attribute in the factory.
"""
function set_optimizer_attribute!(factory::AbstractOptimizerFactory, key::String, value)
    factory.attributes[key] = value
    return factory
end

"""
    merge_optimizer_attributes!(factory::AbstractOptimizerFactory, new_attributes::Dict)

Merge new attributes into the factory's existing attributes.
"""
function merge_optimizer_attributes!(factory::AbstractOptimizerFactory, new_attributes::Dict)
    merge!(factory.attributes, new_attributes)
    return factory
end

# Export main types and functions
export AbstractOptimizerFactory, OptimizerFactory, FunctionOptimizerFactory
export create_optimizer, set_optimizer!
export ipopt_optimizer_factory, highs_optimizer_factory, gurobi_optimizer_factory
export get_optimizer_attributes, set_optimizer_attribute!, merge_optimizer_attributes!