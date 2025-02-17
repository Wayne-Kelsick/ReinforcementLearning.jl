export DoubleLearner

using Random

"""
    DoubleLearner(;L1, L2, rng=Random.default_rng())

This is a meta-learner, it will randomly select one learner and update another learner.
The estimation of an observation is the sum of result from two learners.
"""
Base.@kwdef struct DoubleLearner{T1<:Any,T2<:Any,R<:AbstractRNG} <: Any
    L1::T1
    L2::T2
    rng::R = Random.default_rng()
end

(learner::DoubleLearner)(env) = learner.L1(env) .+ learner.L2(env)

function RLCore.update!(
    L::DoubleLearner{<:TDLearner},
    t::Any,
    ::AbstractEnv,
    ::PostEpisodeStage,
)
    if rand(L.rng, Bool)
        L, Lₜ = L.L1, L.L2
    else
        L, Lₜ = L.L2, L.L1
    end

    S = t[:state]
    A = t[:action]
    R = t[:reward]
    n, γ, Q, Qₜ = L.n, L.γ, L.approximator, Lₜ.approximator
    G = 0.0
    for i in 1:min(n + 1, length(R))
        G = R[end-i+1] + γ * G
        s, a = S[end-i], A[end-i]
        update!(Q, (s, a) => Q(s, a) - G)
    end
end

function Base.push!(L::DoubleLearner{<:TDLearner}, t::Any, ::AbstractEnv, ::PreActStage)
    if rand(L.rng, Bool)
        L, Lₜ = L.L1, L.L2
    else
        L, Lₜ = L.L2, L.L1
    end

    S = t[:state]
    A = t[:action]
    R = t[:reward]
    n, γ, Q, Qₜ = L.n, L.γ, L.approximator, Lₜ.approximator

    if length(R) >= n + 1
        s, a, s′ = S[end-n-1], A[end-n-1], S[end]
        G =
            discount_rewards_reduced(@view(R[end-n:end]), γ) +
            γ^(n + 1) * Qₜ(s′, argmax(Q(s′)))
        update!(Q, (s, a) => Q(s, a) - G)
    end
end

function RLCore.update!(
    t::Any,
    # not very elegant
    ::Union{
        QBasedPolicy{<:DoubleLearner{<:TDLearner}},
        NamedPolicy{<:QBasedPolicy{<:DoubleLearner{<:TDLearner}}},
    },
    ::AbstractEnv,
    ::PreEpisodeStage,
)
    empty!(t)
end
