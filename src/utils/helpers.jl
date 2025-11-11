function __init__()
	print_PowerLASCOPF_version()
end
    
function print_PowerLASCOPF_version()
	v = pkgversion(PowerLASCOPF)
	ascii_art = raw"""
	██████╗  ██████╗ ██╗    ██╗███████╗██████╗ ██╗      █████╗ ███████╗ ██████╗ ██████╗ ██████╗ ███████╗                ██╗██╗     
	██╔══██╗██╔═══██╗██║    ██║██╔════╝██╔══██╗██║     ██╔══██╗██╔════╝██╔════╝██╔═══██╗██╔══██╗██╔════╝                ██║██║     
	██████╔╝██║   ██║██║ █╗ ██║█████╗  ██████╔╝██║     ███████║███████╗██║     ██║   ██║██████╔╝█████╗                  ██║██║     
	██╔═══╝ ██║   ██║██║███╗██║██╔══╝  ██╔══██╗██║     ██╔══██║╚════██║██║     ██║   ██║██╔═══╝ ██╔══╝             ██   ██║██║     
	██║     ╚██████╔╝╚███╔███╔╝███████╗██║  ██║███████╗██║  ██║███████║╚██████╗╚██████╔╝██║     ██║         ██╗    ╚█████╔╝███████╗
	╚═╝      ╚═════╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝         ╚═╝     ╚════╝ ╚══════╝
	"""

	ascii_art *= "POWERED BY: The Julia Programming Language, JuMP,\n NREL/Sienna: PowerSystems.jl, PowerSimulations.jl, & InfrastructureSystems.jl,\n and LANL/ANSI: PowerModels.jl & InfrastructureModels.jl\n"
	ascii_art *= "Version: $(v)"
	println(ascii_art)
	return nothing
end