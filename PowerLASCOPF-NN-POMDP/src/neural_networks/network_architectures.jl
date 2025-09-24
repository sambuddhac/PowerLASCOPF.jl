using Flux

"""
    ActorNetwork

Defines the architecture for the actor network used in the reinforcement learning framework.
"""
struct ActorNetwork
    model::Chain

    function ActorNetwork(input_size::Int, output_size::Int)
        model = Chain(
            Dense(input_size, 128, relu),
            Dense(128, 128, relu),
            Dense(128, output_size, softmax)
        )
        return new(model)
    end
end

"""
    CriticNetwork

Defines the architecture for the critic network used in the reinforcement learning framework.
"""
struct CriticNetwork
    model::Chain

    function CriticNetwork(input_size::Int)
        model = Chain(
            Dense(input_size, 128, relu),
            Dense(128, 128, relu),
            Dense(128, 1)  # Output a single value for the state value
        )
        return new(model)
    end
end

"""
    create_networks

Creates instances of the actor and critic networks with specified input and output sizes.
"""
function create_networks(input_size::Int, output_size::Int)
    actor = ActorNetwork(input_size, output_size)
    critic = CriticNetwork(input_size)
    return actor, critic
end