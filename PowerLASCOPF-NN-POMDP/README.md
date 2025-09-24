# PowerLASCOPF-NN-POMDP

This project integrates neural networks with the PowerLASCOPF optimization framework using the POMDP (Partially Observable Markov Decision Process) approach. The goal is to develop a reinforcement learning-based solution for optimizing power flow in electrical systems.

## Overview

The PowerLASCOPF-NN-POMDP project combines advanced optimization techniques with machine learning to create a robust framework for solving complex power system problems. By leveraging neural networks, the project aims to enhance decision-making processes in power system operations.

## Project Structure

- **src/**: Contains the main source code for the project.
  - **algorithms/**: Implements the ADMM/APP solver and neural policy functions.
  - **policies/**: Defines neural network policies and training utilities.
  - **pomdp/**: Contains POMDP model definitions and state/observation representations.
  - **neural_networks/**: Implements actor and critic networks along with their architectures.
  - **training/**: Contains training loops and experience replay mechanisms.
  - **utils/**: Provides utility functions for data preprocessing and visualization.

- **examples/**: Includes example scripts for training and evaluating the neural network policy.

- **test/**: Contains unit tests for the neural network policy and training processes.

- **Project.toml**: Configuration file listing dependencies and project metadata.

## Setup Instructions

1. **Clone the repository**:
   ```
   git clone <repository-url>
   cd PowerLASCOPF-NN-POMDP
   ```

2. **Install dependencies**:
   Open the Julia REPL and run:
   ```julia
   using Pkg
   Pkg.instantiate()
   ```

3. **Run examples**:
   You can run the example scripts to train and evaluate the neural network policy:
   ```julia
   include("examples/train_neural_policy.jl")
   include("examples/evaluate_policy.jl")
   ```

## Usage

The project provides a framework for integrating neural networks into the PowerLASCOPF optimization process. Users can define their own neural network architectures, training routines, and POMDP models to tailor the solution to specific power system scenarios.

## Contributing

Contributions are welcome! Please submit a pull request or open an issue for any enhancements or bug fixes.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.