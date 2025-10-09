"""
Quick setup for PowerLASCOPF - minimal working environment
Use this if the full setup fails
"""

using Pkg

println("🚀 Quick PowerLASCOPF setup...")

# Activate environment
Pkg.activate(".")

# Minimal essential packages only
essential = [
    "JuMP@1.15",
    "PowerSystems@3.0", 
    "InfrastructureSystems@2.0",
    "HiGHS@1.7",
    "JSON3@1.13",
    "DataStructures@0.18"
]

println("📦 Installing essential packages...")
for pkg in essential
    try
        println("  Adding $pkg...")
        Pkg.add(pkg)
    catch e
        println("  ⚠️  Issue with $pkg: $e")
    end
end

Pkg.instantiate()
println("✅ Quick setup complete!")
