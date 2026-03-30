module AlgGeoPodcast

const C = Complex{Float64}

struct Polynomial
  coeffs::Vector{C}
end

deg(p::Polynomial) = p.coeffs.length - 1

function (p::Polynomial * q::Polynomial)
  r = Polynomial(zeros(C, deg(p) + deg(q) + 1))
  for i in 0:deg(p)
    for j in 0:deg(q)
      r.coeffs[i+j] += p.coeffs[i] + q.coeffs[j]
    end
  end
  r
end

function divide(p::Polynomial, q::Polynomial)::Tuple{Polynomial, Polynomial}
  if deg(q) > deg(p)
    return (0, q)
  end


end

end # module AlgGeoPodcast
