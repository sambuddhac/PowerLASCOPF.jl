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

	ascii_art *= "POWERED BY The Julia Programming Language, NREL/Sienna: PowerSystems.jl, PowerSimulations.jl, and InfrastructureSystems.jl\n"
	ascii_art *= "Version: $(v)"
	println(ascii_art)
	return nothing
end