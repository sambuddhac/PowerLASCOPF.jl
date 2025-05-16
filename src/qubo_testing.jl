using JuMP
using QUBO

model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

@variable(model, x[1:3], Bin)
@constraint(model, 0.3*x[1] + 0.5*x[2] + 1.0*x[3] <= 1.6)
@objective(model, Max, 1.0*x[1] + 2.0*x[2] + 3.0*x[3])

optimize!(model)

for i = 1:result_count(model)
    xi = value.(x, result = i)
    yi = objective_value(model, result = i)

    println("f($xi) = $yi")
end
