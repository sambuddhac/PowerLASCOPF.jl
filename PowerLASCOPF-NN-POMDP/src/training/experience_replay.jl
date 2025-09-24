module ExperienceReplay

using Random

struct Experience
    state::Vector{Float64}
    action::Int
    reward::Float64
    next_state::Vector{Float64}
    done::Bool
end

mutable struct ExperienceReplayBuffer
    buffer::Vector{Experience}
    capacity::Int
    position::Int

    function ExperienceReplayBuffer(capacity::Int)
        return new(Vector{Experience}(), capacity, 1)
    end

    function push!(buffer::ExperienceReplayBuffer, experience::Experience)
        if length(buffer.buffer) < buffer.capacity
            push!(buffer.buffer, experience)
        else
            buffer.buffer[buffer.position] = experience
        end
        buffer.position = mod1(buffer.position, buffer.capacity)
    end

    function sample(buffer::ExperienceReplayBuffer, batch_size::Int)
        indices = rand(1:length(buffer.buffer), batch_size)
        return [buffer.buffer[i] for i in indices]
    end

    function size(buffer::ExperienceReplayBuffer)
        return length(buffer.buffer)
    end
end

end