# You might define a specific formulation for your GenSolver
struct LASCOPFGeneratorFormulation <: _PSim.AbstractDeviceFormulation end

# Or, if your GenSolver is more of a "service" or overall problem type:
# struct LASCOPFServiceFormulation <: PSI.AbstractServiceFormulation end