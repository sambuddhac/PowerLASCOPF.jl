"""
Core type definitions for PowerLASCOPF.jl

This module defines the fundamental abstract types and interfaces
used throughout the PowerLASCOPF.jl package.
"""

using PowerSystems
using InfrastructureSystems
const IS = InfrastructureSystems
const PSY = PowerSystems

# ===== ABSTRACT TYPE HIERARCHY =====

"""
Abstract base type for all PowerLASCOPF components.
"""
abstract type PowerLASCOPFComponent end

"""
Abstract type for power system subsystems (e.g., nodes, areas).
"""
abstract type Subsystem <: PowerLASCOPFComponent end

"""
Abstract type for power system devices (e.g., lines, transformers).
"""
abstract type Device <: PowerLASCOPFComponent end

"""
Abstract type for power generators with optimization capabilities.
"""
abstract type PowerGenerator <: Device end

"""
Abstract type for network solvers and algorithms.
"""
abstract type AbstractSolver end

"""
Abstract type for ADMM/PMP algorithm components.
"""
abstract type AbstractADMMComponent end

"""
Abstract type for APP (Auxiliary Problem Principle) components.
"""
abstract type AbstractAPPComponent end

# ===== ALGORITHM STATE TYPES =====

"""
Abstract type for interval types in multi-period optimization.
"""
abstract type IntervalType end

"""
Abstract type for generator interval types.
"""
abstract type GenIntervals <: IntervalType end

"""
Abstract type for line interval types.
"""
abstract type LineIntervals <: IntervalType end

# ===== OPTIMIZATION MODEL TYPES =====

"""
Abstract type for optimization models.
"""
abstract type AbstractModel end

"""
Abstract type for cost functions.
"""
abstract type AbstractCost end

"""
Abstract type for constraint sets.
"""
abstract type AbstractConstraints end

# ===== SYSTEM INTEGRATION TYPES =====

"""
Abstract type for system extensions and integrations.
"""
abstract type SystemExtension end

"""
Abstract type for external package integrations.
"""
abstract type PackageIntegration <: SystemExtension end

# Export all abstract types
export PowerLASCOPFComponent, Subsystem, Device, PowerGenerator
export AbstractSolver, AbstractADMMComponent, AbstractAPPComponent
export IntervalType, GenIntervals, LineIntervals
export AbstractModel, AbstractCost, AbstractConstraints
export SystemExtension, PackageIntegration