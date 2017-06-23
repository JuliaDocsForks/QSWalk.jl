#glue distribution over abstraction classess
function glue_distrib(A::Vector{Float64},tab::Array{Array{Int64}})
    B = Float64[]
    for i = 1:length(tab)
        suma = 0
        for j in tab[i]
            suma += A[j]
        end
        push!(B,suma)
    end
    return B
end

function rotating_hamiltonian(macierz::Matrix{Complex128}, klasy_abstrakcji::Vector{Array{Int64}})
    ######random line segment
    hamiltonians = SparseMatrixCSC{Complex128,Int64}[]
    for k in klasy_abstrakcji
        H = zeros(macierz)
        for i = 1:(length(k)-1)
            a, b = k[i], k[i+1]
            H += im*ketbra(a,b,size(macierz)[1])
        end
        H += H'
        push!(hamiltonians,H)
    end
    return sparse(sum(hamiltonians))
end

function enlarged_lindblad(L::SparseMatrixCSC{Complex128,Int64})
    ####w wyniku otrzymujemy macierz z rownymi wagami, przyjmujemy z roznymi wagami, ale zwraca z jedynkami
    klasy_abstrakcji = Array{Int64}[]
    n = size(L)[1]
    st = n + 1
    en = 0
    for i = 1:n
        en = st + countnz(L[i,:])-2
        if en>=st
            push!(klasy_abstrakcji,vcat(i,collect(st:en)))
            st = en+1
        elseif en-st < 0
            push!(klasy_abstrakcji,[i])
        end

    end

    #####################################################
    macierz = zeros(Complex128,(length(vcat(klasy_abstrakcji...)),length(vcat(klasy_abstrakcji...))))

    for i = 1:n
        klasy_wchodzace = find(L[i,:].!=0)
        for j in klasy_wchodzace
            for k in klasy_abstrakcji[j], l in klasy_abstrakcji[i]
                macierz[l,k] = 1
            end
        end
    end
    ########################hamiltoniany dla roznych klas abstrakcji
    hamiltonian = rotating_hamiltonian(macierz,klasy_abstrakcji)

    for i = 1:n
        klasy_wchodzace = find(L[i,:].!=0)
        n_kl = length(klasy_abstrakcji[i])
        a = 0
        for j in klasy_wchodzace
            for k in klasy_abstrakcji[j]
                b = 0
                for l in klasy_abstrakcji[i]
                    macierz[l,k] = exp(im*2*b*a*pi/n_kl)
                    b += 1
                end
            end
            a += 1
        end
    end
    L = SparseMatrixCSC{Complex128,Int64}[]
    push!(L,sparse(macierz))
    return (L, klasy_abstrakcji, hamiltonian)
end
