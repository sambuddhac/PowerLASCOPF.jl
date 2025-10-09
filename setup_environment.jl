"""
Setup script for PowerLASCOPF Julia environment
Run this script to create a working Julia environment with all dependencies
"""

using Pkg

println("🚀 Setting up PowerLASCOPF Julia environment...")

# Activate the current directory as a Julia project
println("📁 Activating project environment...")
Pkg.activate(".")

# Remove problematic packages that might cause conflicts
problematic_packages = [
    "HydroPowerSimulations",  # Often causes conflicts
    "MathProgBase"            # Deprecated package
]

println("🧹 Cleaning up potentially problematic packages...")
for pkg in problematic_packages
    try
        Pkg.rm(pkg)
        println("  ✅ Removed $pkg")
    catch e
        println("  ℹ️  $pkg not found (this is fine)")
    end
end

# Update registry first
println("📋 Updating package registry...")
try
    Pkg.Registry.update()
    println("  ✅ Registry updated")
catch e
    println("  ⚠️  Registry update failed: $e")
end

# Core dependencies that must be installed first
core_deps = [
    "JuMP",
    "PowerSystems", 
    "InfrastructureSystems",
    "DataStructures",
    "JSON3",
    "Distributions"
]

println("🔧 Installing core dependencies...")
for dep in core_deps
    try
        println("  Installing $dep...")
        Pkg.add(dep)
        println("  ✅ $dep installed")
    catch e
        println("  ❌ Failed to install $dep: $e")
    end
end

# Optimization solvers
solver_deps = [
    "HiGHS",
    "GLPK", 
    "Ipopt"
]

println("🎯 Installing optimization solvers...")
for dep in solver_deps
    try
        println("  Installing $dep...")
        Pkg.add(dep)
        println("  ✅ $dep installed")
    catch e
        println("  ❌ Failed to install $dep: $e")
    end
end

# POMDP and RL dependencies
ai_deps = [
    "POMDPs",
    "POMDPTools",
    "PyCall"
]

println("🤖 Installing AI/ML dependencies...")
for dep in ai_deps
    try
        println("  Installing $dep...")
        Pkg.add(dep)
        println("  ✅ $dep installed")
    catch e
        println("  ❌ Failed to install $dep: $e")
    end
end

# Visualization and utilities
viz_deps = [
    "Plots",
    "PlotlyJS",
    "Colors",
    "GraphRecipes",
    "Graphs",
    "NetworkLayout"
]

println("📊 Installing visualization dependencies...")
for dep in viz_deps
    try
        println("  Installing $dep...")
        Pkg.add(dep)
        println("  ✅ $dep installed")
    catch e
        println("  ❌ Failed to install $dep: $e")
    end
end

# Data handling
data_deps = [
    "CSV",
    "DataFrames",
    "TimeSeries",
    "YAML",
    "BenchmarkTools",
    "StatsBase"
]

println("📈 Installing data handling dependencies...")
for dep in data_deps
    try
        println("  Installing $dep...")
        Pkg.add(dep)
        println("  ✅ $dep installed")
    catch e
        println("  ❌ Failed to install $dep: $e")
    end
end

# Try to install PowerModels and PowerSimulations
power_deps = [
    "PowerModels",
    "PowerSimulations"
]

println("⚡ Installing Power System dependencies...")
for dep in power_deps
    try
        println("  Installing $dep...")
        Pkg.add(dep)
        println("  ✅ $dep installed")
    catch e
        println("  ⚠️  Failed to install $dep: $e")
        println("     This might be due to version conflicts - will try to resolve...")
    end
end

# Instantiate the environment
println("🔨 Instantiating environment...")
try
    Pkg.instantiate()
    println("  ✅ Environment instantiated successfully")
catch e
    println("  ⚠️  Instantiation had issues: $e")
    println("     Trying to resolve dependencies...")
    try
        Pkg.resolve()
        println("  ✅ Dependencies resolved")
    catch e2
        println("  ❌ Could not resolve dependencies: $e2")
    end
end

# Precompile packages
println("⚙️  Precompiling packages...")
try
    Pkg.precompile()
    println("  ✅ Precompilation completed")
catch e
    println("  ⚠️  Precompilation had issues: $e")
end

# Status check
println("\n📋 Final environment status:")
Pkg.status()

# Test critical packages
println("\n🧪 Testing critical package imports...")
critical_packages = [
    "PowerSystems" => "PSY",
    "JuMP" => "JuMP", 
    "HiGHS" => "HiGHS",
    "JSON3" => "JSON3",
    "POMDPs" => "POMDPs"
]

all_working = true
for (pkg, alias) in critical_packages
    try
        eval(Meta.parse("using $pkg"))
        println("  ✅ $pkg imports successfully")
    catch e
        println("  ❌ $pkg failed to import: $e")
        all_working = false
    end
end

if all_working
    println("\n🎉 Environment setup completed successfully!")
    println("   You can now use: using Pkg; Pkg.activate(\".\")")
else
    println("\n⚠️  Environment setup completed with some issues.")
    println("   Some packages may need manual installation or version resolution.")
end

println("\n💡 Next steps:")
println("   1. Restart Julia")
println("   2. Run: using Pkg; Pkg.activate(\".\")")
println("   3. Test with: using PowerSystems, JuMP, HiGHS")
