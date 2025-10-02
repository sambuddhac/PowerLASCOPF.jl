<h1>
<img src="https://lh3.googleusercontent.com/rd-gg/AAHar4dbo_JTN7Ndg7oUGME3oyerEUxk8_5-nQtUIb2rPo1TgzOjKtTImku_vZ5KSTcdDhiIngYZAC77Sia-mK6Vq2IEkJsdxMJ1IOBUodm5kx-NescJwhMrh0ISEk79PMWenFuCkmRJb8HU1vp48I6tV9pi5ZipWAC0ersN1hNN2gfm0_mOOp8GYUOYRzC67WWkpYaAmfabsQD2p2tuoZHVJ3z9_Vg9hDcsphWJyTKNCRZ9p7jYMhEnOSdTlu8sY7O_FE6o5XDARL_zFoX4ZAOMGoVEURc9GLA8Uuqj8a7ULJfXaAXGmyZLDFjttsKbnM5Yp-81fMO8We9j2_IQrhERxtarO1bCvwg1apC_ll2e19gL9WgAh_ANYLtLygi4Yr-onXSt_hrgJ415nrtbLAjUV0Dmt7iM3XWGf-50b3p9nUdwbkTPwsICaxz8ZKORV6gXtnAcXTFN0fpsYPVTCsi24L00ebenjkCrSQEPCWaxNhbbYzbT9lydBpC5Ng0QmeRqllOaqhnzxxQthgIEUqU264PVu9aTz695msj1dNxZ0Dp8cABZlF-NeNz6fgIDh7p0fXB1-UcH1ir40_Lw4eteeQVMIKX45dhHeOcJCdZ0BjDl250wlpm7fCGrqT-_3KWwucay43VdgIjtKPjtMkHKXf3bbkFTCxp2DZiQVwsjU7_Y8njxMZveOgE9rNZm-N_fZ330pDQ88pdxMhn0esLdBTRJWqOqdnn9CiDgYiX47VyzxSkJsTT4KueuQzwPiEwyaSEl-IZhyU2VQva4Kr__uG5Zt3E5kw4v3w5Xes96EraZiKOKOmL-MxM4ph__hWeeCDPDrL3TMGh8xPDkDBjsS_XzAFbth3JnfhAvRntZ-NXOCmg19jKidHVVq4LSorwsV_6Yvl0Za8vA_V4PTDhmgXq6jqL5GtsemCB3me18I1z9Ks8kJy6km82DV9_7G9ai6N1D15oVX4T8NRmTSckHXKEvNhKGXzeoGwAZwuY8fsD5fusXwhkVjdML3Ykpch2d_S1G-a-ZSA4QMkMrqt1mBIh3lqQi11z9u8ak5p2jnfrHrPCCKVw4rTBarfxjANghUJL0vV7_J-TlzuTmwWw17Fv0QnEMKNzl6xRWlw2X3mgE1ZdA7mWk-6kEGjtGlLn7xg0zqGNwXH1QjiPduINO7FL1f9gNyRapmnIssMa5Gqf_ul8ooDtijCvG2mz6F1GBIfbMIB6OHsKkA6DIdOmwz2KJV_rDWUN4qvepcVb1nhE0MBfVqN3oFOg106Un9nZzCzO1LrUh4XyZz-egxIZ43mRiA16BS7Aq-MlNScD0_bi9dalpdK1Aq50TlMFYOYa-Ltg=s1024" alt="PowerLASCOPF.jl Logo" height="48" style="vertical-align: middle; margin-right: 15px;">


PowerLASCOPF.jl
</h1>

# PowerLASCOPF [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://sambuddhac.github.io/PowerLASCOPF.jl/stable) [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://sambuddhac.github.io/PowerLASCOPF.jl/dev) [![Build Status](https://github.com/sambuddhac/PowerLASCOPF.jl/badges/master/pipeline.svg)](https://github.com/sambuddhac/PowerLASCOPF.jl/pipelines) [![Coverage](https://github.com/sambuddhac/PowerLASCOPF.jl/badges/master/coverage.svg)](https://github.com/sambuddhac/PowerLASCOPF.jl/commits/master) [![Build Status](https://travis-ci.com/sambuddhac/PowerLASCOPF.jl.svg?branch=master)](https://travis-ci.com/sambuddhac/PowerLASCOPF.jl) [![Build Status](https://ci.appveyor.com/api/projects/status/github/sambuddhac/PowerLASCOPF.jl?svg=true)](https://ci.appveyor.com/project/sambuddhac/PowerLASCOPF-jl) [![Build Status](https://cloud.drone.io/api/badges/sambuddhac/PowerLASCOPF.jl/status.svg)](https://cloud.drone.io/sambuddhac/PowerLASCOPF.jl) [![Build Status](https://api.cirrus-ci.com/github/sambuddhac/PowerLASCOPF.jl.svg)](https://cirrus-ci.com/github/sambuddhac/PowerLASCOPF.jl) [![Coverage](https://codecov.io/gh/sambuddhac/PowerLASCOPF.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/sambuddhac/PowerLASCOPF.jl) [![Coverage](https://coveralls.io/repos/github/sambuddhac/PowerLASCOPF.jl/badge.svg?branch=master)](https://coveralls.io/github/sambuddhac/PowerLASCOPF.jl?branch=master) [![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)
PowerLASCOPF.jl is an integrated software tool for simulating power flow (PF), optimal power flow (OPF), security constrained optimal power flow (SCOPF), look ahead security constrained optimal power flow (LASCOPF) for both with and without line temperatute limiting and restoration of flows. It is written in Julia and implements functionalitties of other similar packages like PowerModels.jl, PowerSimulations.jl etc. It also has a ground-up design featuring both a centralized as well as a distibuted solver (using ADMM and APP algorithms). 

PowerLASCOPF incorporates smart loads like EV charging and is aimed at incorporating other infrastructures like gas pipeline network in the foreseeable future.

Introduction
PowerLASCOPF.jl is a specialized optimization package built on top of NREL/Sienna's core Julia packages (PowerSystems.jl, PowerSimulations.jl, and InfrastructureSystems.jl) designed to solve Large Area System Constrained Optimal Power Flow (LASCOPF) problems.

This package provides custom structural components and data handling capabilities optimized for large-scale power system modeling and high-performance computation within the Julia ecosystem.

Key Features
Customized Optimization Container: Utilizes a custom instantiation of the PowerSimulations.OptimizationContainer tailored for LASCOPF constraints.

Scalable Modeling: Focuses on efficient data representation for large-scale system analysis.

Integration: Seamlessly integrates with existing PSI and PSY data structures and functionality.

Installation
using Pkg
Pkg.add("PowerLASCOPF") # (Assuming this will be the package name)

