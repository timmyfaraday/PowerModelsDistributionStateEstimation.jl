# Mathematical Model of the State Estimation Criteria

Let `Xₘ` be the random variable associated to a measurement `m ∈ 𝓜` and `xₘ ∈ 𝓧` 
the related variable, where:
* `𝓜` denotes the set of measurements,
* `𝓧` denotes the (extended) variable space of the OPF problem.

Currently, the following univariate continuous distributions are supported through
the [Distributions.jl](https://github.com/JuliaStats/Distributions.jl) package:
- Exponential
- Weibull
- Normal
- Log-Normal
- Gamma
- Beta
- Extended Beta
```@docs
ExtendedBeta
```

The state of a power system can be determined based on a specific estimation 
criterion. The state estimator criteria can be classified into two groups based 
on the random variable `Xₘ`:
- `Gaussian`
	* `wlav`: weighted least absolute value (exact)
	* `rwlav`: relaxed weighted least absolute value (exact relaxation)
    * `wls`: weighted least square (exact)
    * `rwls`: relaxed weighted least square (exact relaxation)
- `Non-Gaussian`
    * `gmm`: Gaussian mixture model (approximation)
    * `mle`: maximum likelihood estimation (exact)

The user has to specify the `criterion` through the `se_settings` ([Input Data Format](@ref)).
If no criterion is specified, it will default to `rwlav` in the Gaussian case 
and `mle` in the non-Gaussian case.

To use a `mixed` criterion, it is not sufficient to set the `criterion` in 
`se_settings` as `mixed`. In addition to this, an individual dictionary entry 
for every measurement in `data["meas"]` needs to be added, to state which 
criterion is associated to each measurement.
The individual criterion entry needs to be placed under a `crit` key. For example:
`data["meas"]["1"]["crit"] = "rwlav"` and `data["meas"]["2"]["crit"] = "mle"`.
A basic function to assign different criteria to different measurement is provided:
```@docs
PowerModelsDistributionStateEstimation.assign_default_individual_criterion!(data; chosen_criterion="rwlav")
```

Furthermore, a rescaler can be introduced to improve the convergence of the state
estimation. The user has to specify the `rescaler` through the `se_settings` ([Input Data Format](@ref)).
If no rescaler is specified, it will default to `1.0`.

## Gaussian State Estimation Criteria

### WLAV and rWLAV

The WLAV criterion represents the absolute value norm (p=1) and is given by
```math
\begin{eqnarray}
      \rho_{m}          &= \frac{| x - \mu_{m} |}{\text{rsc} \cdot \sigma_{m}},\quad m \in \mathcal{M}: m \to x \in \mathcal{X},
\end{eqnarray}
```
where:
* `ρ` denotes the residual associated with a measurement $m$,
* `x` denotes the variable corresponding to a measurement $m$.
* `μ` denotes the measured value, i.e., expectation `𝐄(Xₘ)`,
* `σ` denotes the the measurement error, i.e., standard deviation `√(𝐕(Xₘ))`,
* `rsc` denotes the rescaler.

Solving a state estimation using the WLAV criterion is non-trivial as the
absolute value function is not continuously differentiable. This drawback is
lifted by its exact linear relaxation: rWLAV[^1]. The rWLAV criterion is given by

```math
\begin{eqnarray}
      \rho_{m}          &\geq \frac{ x_{m} - \mu_{m} }{\text{rsc} \cdot \sigma_{m}},\quad m \in \mathcal{M}: m \to x_{m} \in \mathcal{X},    \\
      \rho_{m}          &\geq - \frac{ x_{m} - \mu_{m} }{\text{rsc} \cdot \sigma_{m}},\quad m \in \mathcal{M}: m \to x_{m} \in \mathcal{X},    \\
\end{eqnarray}
```

[^1]: Note that this relaxation is only exact in the context of minimization problem.

## WLS and rWLS

The WLS criterion represents the Eucledian norm (p=2) and is given by
```math
\begin{eqnarray}
      \rho_{m}          &= \frac{( x_{m} - \mu_{m} )^{2}}{\text{rsc} \cdot \sigma_{m}^{2}},\quad m \in \mathcal{M}: m_{m} \to x \in \mathcal{X}.
\end{eqnarray}
```
The rWLS criterion relaxes the former as a cone and is given by
```math
\begin{eqnarray}
      rsc \cdot \sigma_{m}^{2} \cdot \rho_{m} &\geq ( x_{m} - \mu_{m} )^{2},\quad m \in \mathcal{M}: m \to x_{m} \in \mathcal{X}.
\end{eqnarray}
```

## Non-Gaussian State Estimation Criteria

## Gaussian Mixture Estimation

The Gaussian mixture criterion splits the random variable `Xₘ` into Gaussian 
components `Xₙ`, and introduces two constraints. First, the related variable `xₘ`
is the sum of the variables `xₙ` related to the Gaussian components. Second, the 
overall residual `ρₘ` equal to the sum of Gaussian components' residuals. The 
`rwlav` criterion is choosen to model the residual of the Gaussian components.

```math
\begin{eqnarray}
      x_{m}             &= \sum_{m \to n \in \mathcal{N}} x_{n},\quad m \in \mathcal{M}: m \to x_{m} \in \mathcal{X}                                  \\
      \rho_{m}          &\geq \sum_{m \to n \in \mathcal{N}} \frac{ x_{n} - \mu_{n} }{\text{rsc} \cdot w_{n} \sigma_{n}},\quad m \in \mathcal{M},     \\
      \rho_{m}          &\geq - \sum_{m \to n \in \mathcal{N}} \frac{ x_{n} - \mu_{n} }{\text{rsc} \cdot w_{n} \sigma_{m}},\quad m \in \mathcal{M},   \\
\end{eqnarray}
```
where:
* `w` denotes the weight associated with a Gaussian component $n$.

The user has to specify the `number_of_gaussian` through the `se_settings` ([Input Data Format](@ref)). 
If no number is specified, it will default to `10`.

## Maximum Likelihood Estimation

The maximum likelihood criterion links the measurement residual to the logpdf of
the associated distribution and is given by
```math
\begin{eqnarray}
      \rho_{m}          &= - \text{rsc} \cdot \text{logpdf}_{m}(x) + \text{shf},\quad m \in \mathcal{M}: m \to x \in \mathcal{X}.
\end{eqnarray}
```
where `shf` denotes a shift setting the minimum value of the residual to zero.

To avoid the use of automatic differentiation, the first derivative (`gradlogpdf`)
is provided by Distributions.jl and the second derivative (`heslogpdf`) is provided internally.