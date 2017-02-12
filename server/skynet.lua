--- Skynet server. Used for employing all parts of the NEAT algorithm apart from the evaluation function.
-- Based on MarI/O code by SethBling
-- Feel free to use this code, but please do not redistribute it.

--- The number of inputs.
-- Should match the constants in NeuralNetwork.as
Inputs = 32
--- The number of outputs.
-- Should match the constants in NeuralNetwork.as
Outputs = 6

--- The max size of the population.
Population = 300
--- The coefficient applied to the disjoint value in the delta function.
DeltaDisjoint = 2.0
--- The coefficient applied to the weights value in the delta function.
DeltaWeights = 0.4
--- The threshold that determines whether two genomes are in the same species using the delta function.
DeltaThreshold = 1.0

--- The number of generations before a species is marked as stale and culled.
StaleSpecies = 15

--- The chance that pointMutate is called on each generation.
--@see pointMutate
MutateConnectionsChance = 0.25
--- The chance to perturb weights or randomly change them during pointMutate.
--@see pointMutate
PerturbChance = 0.90
--- The chance to perform crossover during breedChild.
--@see breedChild
CrossoverChance = 0.75
--- The chance to perform linkMutate on each generation.
--@see linkMutate
LinkMutationChance = 2.0
--- The chance to perform nodeMutate.
--@see nodeMutate
NodeMutationChance = 0.50
--- The chance to perform linkMutate with forcedBias enabled.
--@see linkMutate
BiasMutationChance = 0.40
--- A coefficient effecting how much the weights are perturbed during mutation.
StepSize = 0.1
--- The chance to cause a disabling mutation.
--@see enableDisableMutate
DisableMutationChance = 0.4
--- The chance to cause an enabling mutation.
--@see enableDisableMutate
EnableMutationChance = 0.2

--- The maximum number of nodes in the network.
MaxNodes = 1000000

--- The file to save/load state from.
SaveLoadFile = "initrun.txt"

--- computes a sigmoid function on x.
--@return a number
function sigmoid(x)
	return 2/(1+math.exp(-4.9*x))-1
end

--- Increments the global innovation number and returns it.
function newInnovation()
	pool.innovation = pool.innovation + 1
	return pool.innovation
end

--- Creates a new Pool.
--@return Pool
function newPool()
	local pool = {}
	pool.species = {}
	pool.generation = 0
	pool.innovation = Outputs
	pool.currentSpecies = 1
	pool.currentGenome = 1
	pool.currentFrame = 0
	pool.maxFitness = 0
	
	return pool
end

--- Creates a new Species.
--@return Species
function newSpecies()
	local species = {}
	species.topFitness = 0
	species.staleness = 0
	species.genomes = {}
	species.averageFitness = 0
	
	return species
end

--- Creates a new Genome.
--@return Genome
function newGenome()
	local genome = {}
	genome.genes = {}
	genome.fitness = 0
	genome.adjustedFitness = 0
	genome.network = {}
	genome.maxneuron = 0
	genome.globalRank = 0
	genome.mutationRates = {}
	genome.mutationRates["connections"] = MutateConnectionsChance
	genome.mutationRates["link"] = LinkMutationChance
	genome.mutationRates["bias"] = BiasMutationChance
	genome.mutationRates["node"] = NodeMutationChance
	genome.mutationRates["enable"] = EnableMutationChance
	genome.mutationRates["disable"] = DisableMutationChance
	genome.mutationRates["step"] = StepSize
	
	return genome
end

--- Shallow copies a Genome.
--@return Genome
function copyGenome(genome)
	local genome2 = newGenome()
	for g=1,#genome.genes do
		table.insert(genome2.genes, copyGene(genome.genes[g]))
	end
	genome2.maxneuron = genome.maxneuron
	genome2.mutationRates["connections"] = genome.mutationRates["connections"]
	genome2.mutationRates["link"] = genome.mutationRates["link"]
	genome2.mutationRates["bias"] = genome.mutationRates["bias"]
	genome2.mutationRates["node"] = genome.mutationRates["node"]
	genome2.mutationRates["enable"] = genome.mutationRates["enable"]
	genome2.mutationRates["disable"] = genome.mutationRates["disable"]
	
	return genome2
end

--- Creates a new Genome, gives it a maxneuron equal to Inputs, and mutates it once.
--@return Genome
function basicGenome()
	local genome = newGenome()
	local innovation = 1

	genome.maxneuron = Inputs
	mutate(genome)
	
	return genome
end

--- Creates a new Gene.
--@return Gene
function newGene()
	local gene = {}
	gene.into = 0
	gene.out = 0
	gene.weight = 0.0
	gene.enabled = true
	gene.innovation = 0
	
	return gene
end

--- Shallow copies a Gene.
--@return Gene
function copyGene(gene)
	local gene2 = newGene()
	gene2.into = gene.into
	gene2.out = gene.out
	gene2.weight = gene.weight
	gene2.enabled = gene.enabled
	gene2.innovation = gene.innovation
	
	return gene2
end

--- Creates a new Neuron.
--@return Neuron
function newNeuron()
	local neuron = {}
	neuron.incoming = {}
	neuron.value = 0.0
	
	return neuron
end

--- Creates a network phenotype from a genome.
-- Assigns the network property of the genome to the new network.
function generateNetwork(genome)
    -- TODO: Make this into the string repr for the network
	local network = {}
	network.neurons = {}
	
	for i=1,Inputs do
		network.neurons[i] = newNeuron()
	end
	
	for o=1,Outputs do
		network.neurons[MaxNodes+o] = newNeuron()
	end
	
	table.sort(genome.genes, function (a,b)
		return (a.out < b.out)
	end)
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if gene.enabled then
			if network.neurons[gene.out] == nil then
				network.neurons[gene.out] = newNeuron()
			end
			local neuron = network.neurons[gene.out]
			table.insert(neuron.incoming, gene)
			if network.neurons[gene.into] == nil then
				network.neurons[gene.into] = newNeuron()
			end
		end
	end
	
	genome.network = network
end

--- Runs a network on the given inputs.
--@return table of outputs
function evaluateNetwork(network, inputs)
	table.insert(inputs, 1)
	if #inputs ~= Inputs then
		console.writeline("Incorrect number of neural network inputs.")
		return {}
	end
	
	for i=1,Inputs do
		network.neurons[i].value = inputs[i]
	end
	
	for _,neuron in pairs(network.neurons) do
		local sum = 0
		for j = 1,#neuron.incoming do
			local incoming = neuron.incoming[j]
			local other = network.neurons[incoming.into]
			sum = sum + incoming.weight * other.value
		end
		
		if #neuron.incoming > 0 then
			neuron.value = sigmoid(sum)
		end
	end
	
	local outputs = {}
	for o=1,Outputs do
		local button = "P1 " .. ButtonNames[o]
		if network.neurons[MaxNodes+o].value > 0 then
			outputs[button] = true
		else
			outputs[button] = false
		end
	end
	
	return outputs
end

--- Performs crossover on two Genomes.
-- Genes with the same innovation number are randomly chosen from either parent.
-- Excess/disjoint genes are taken from the higher fitness parent.
-- Mutation rates are taken from the higher fitness parent.
-- Child maxneuron is max(g1.maxneuron, g2.maxneuron)
--@param g1 Genome
--@param g2 Genome
--@return child Genome
function crossover(g1, g2)
	-- Make sure g1 is the higher fitness genome
	if g2.fitness > g1.fitness then
		tempg = g1
		g1 = g2
		g2 = tempg
	end

	local child = newGenome()
	
	local innovations2 = {}
	for i=1,#g2.genes do
		local gene = g2.genes[i]
		innovations2[gene.innovation] = gene
	end
	
	for i=1,#g1.genes do
		local gene1 = g1.genes[i]
		local gene2 = innovations2[gene1.innovation]
		if gene2 ~= nil and math.random(2) == 1 and gene2.enabled then
			table.insert(child.genes, copyGene(gene2))
		else
			table.insert(child.genes, copyGene(gene1))
		end
	end
	
	child.maxneuron = math.max(g1.maxneuron,g2.maxneuron)
	
	for mutation,rate in pairs(g1.mutationRates) do
		child.mutationRates[mutation] = rate
	end
	
	return child
end

--- Given a list of Genes, returns a random Neuron number.
--@param genes a list of Genes
--@param nonInput a boolean. Set this to true if you DONT want an input neuron.
function randomNeuron(genes, nonInput)
	local neurons = {}
	if not nonInput then
		for i=1,Inputs do
			neurons[i] = true
		end
	end
	for o=1,Outputs do
		neurons[MaxNodes+o] = true
	end
	for i=1,#genes do
		if (not nonInput) or genes[i].into > Inputs then
			neurons[genes[i].into] = true
		end
		if (not nonInput) or genes[i].out > Inputs then
			neurons[genes[i].out] = true
		end
	end

	local count = 0
	for _,_ in pairs(neurons) do
		count = count + 1
	end
    -- n is a random index for a neuron in the list
	local n = math.random(1, count)
	
    -- k is a neuron number
	for k,v in pairs(neurons) do
		n = n-1
		if n == 0 then
			return k
		end
	end
	
	return 0
end

--- Determines whether the given set of genes contains the given link.
-- The equality function compares the gene's 'into' and 'out' properties with the link.
--@param genes list of Genes
--@param link a table with properties 'into' and 'out'
function containsLink(genes, link)
	for i=1,#genes do
		local gene = genes[i]
		if gene.into == link.into and gene.out == link.out then
			return true
		end
	end
end

--- Mutate the weights for each gene in a genome.
-- Uses a step size according to genome.mutationRates["step"]
-- If rand < PerturbChance then the weight is perturbed
-- Else a random value is assigned to the weight
--@param genome Genome
--@see StepSize
--@see PerturbChance
function pointMutate(genome)
	local step = genome.mutationRates["step"]
	
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if math.random() < PerturbChance then
			gene.weight = gene.weight + math.random() * step*2 - step
		else
			gene.weight = math.random()*4-2
		end
	end
end

--- Creates a new gene (link between 2 existing nodes) and inserts it into the genome.
-- Has a chance to not create a new gene if it happens to choose 2 input nodes.
-- Also will not create a new gene if by chance the new link is already in the genome.
--@param genome Genome
--@param forceBias boolean, if true then the new gene's 'into' is set to the value of Inputs 
--@see Inputs
--@see containsLink
function linkMutate(genome, forceBias)
	local neuron1 = randomNeuron(genome.genes, false) -- can be an input node
	local neuron2 = randomNeuron(genome.genes, true) -- cannot be an input node
	 
	local newLink = newGene()
	if neuron1 <= Inputs and neuron2 <= Inputs then
		--Both input nodes
		return
	end
	if neuron2 <= Inputs then
		-- Swap output and input
		local temp = neuron1
		neuron1 = neuron2
		neuron2 = temp
	end

	newLink.into = neuron1
	newLink.out = neuron2
	if forceBias then
		newLink.into = Inputs
	end
	
	if containsLink(genome.genes, newLink) then
		return
	end
	newLink.innovation = newInnovation()
	newLink.weight = math.random()*4-2
	
	table.insert(genome.genes, newLink)
end

--- Selects a random enabled gene from the genome and creates a new Neuron at its midpoint.
-- Does nothing if the genome has no genes.
-- Increments genome.maxneuron
--@param genome Genome
function nodeMutate(genome)
	if #genome.genes == 0 then
		return
	end

	genome.maxneuron = genome.maxneuron + 1

	local gene = genome.genes[math.random(1,#genome.genes)]
	if not gene.enabled then
		return
	end
	gene.enabled = false
	
	local gene1 = copyGene(gene)
	gene1.out = genome.maxneuron
	gene1.weight = 1.0
	gene1.innovation = newInnovation()
	gene1.enabled = true
	table.insert(genome.genes, gene1)
	
	local gene2 = copyGene(gene)
	gene2.into = genome.maxneuron
	gene2.innovation = newInnovation()
	gene2.enabled = true
	table.insert(genome.genes, gene2)
end

--- Flips the enabled state of a random gene in the genome.
--@param genome Genome
--@param enable If true then disabled genes are considered for flipping. If false then enabled genes.
function enableDisableMutate(genome, enable)
	local candidates = {}
	for _,gene in pairs(genome.genes) do
		if gene.enabled == not enable then
			table.insert(candidates, gene)
		end
	end
	
	if #candidates == 0 then
		return
	end
	
	local gene = candidates[math.random(1,#candidates)]
	gene.enabled = not gene.enabled
end

--- Applies all the kinds of mutations to a genome, if a random test succeeds for each one.
-- Also perturbs the genome.mutationRates for each mutation.
--@see pointMutate
--@see linkMutate
--@see nodeMutate
--@see enableDisableMutate
function mutate(genome)
	for mutation,rate in pairs(genome.mutationRates) do
		if math.random(1,2) == 1 then
			genome.mutationRates[mutation] = 0.95*rate
		else
			genome.mutationRates[mutation] = 1.05263*rate
		end
	end

	if math.random() < genome.mutationRates["connections"] then
		pointMutate(genome)
	end
	
	local p = genome.mutationRates["link"]
	while p > 0 do
		if math.random() < p then
			linkMutate(genome, false)
		end
		p = p - 1
	end

	p = genome.mutationRates["bias"]
	while p > 0 do
		if math.random() < p then
			linkMutate(genome, true)
		end
		p = p - 1
	end
	
	p = genome.mutationRates["node"]
	while p > 0 do
		if math.random() < p then
			nodeMutate(genome)
		end
		p = p - 1
	end
	
	p = genome.mutationRates["enable"]
	while p > 0 do
		if math.random() < p then
			enableDisableMutate(genome, true)
		end
		p = p - 1
	end

	p = genome.mutationRates["disable"]
	while p > 0 do
		if math.random() < p then
			enableDisableMutate(genome, false)
		end
		p = p - 1
	end
end

--- Returns a number indicating how disjoint two genes are.
-- The formula used is "numDisjointGenes / max(#genes1, #genes2)
--@return a number between 0 and 1
function disjoint(genes1, genes2)
	local i1 = {}
	for i = 1,#genes1 do
		local gene = genes1[i]
		i1[gene.innovation] = true
	end

	local i2 = {}
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = true
	end
	
	local disjointGenes = 0
	for i = 1,#genes1 do
		local gene = genes1[i]
		if not i2[gene.innovation] then
			disjointGenes = disjointGenes+1
		end
	end
	
	for i = 1,#genes2 do
		local gene = genes2[i]
		if not i1[gene.innovation] then
			disjointGenes = disjointGenes+1
		end
	end
	
	local n = math.max(#genes1, #genes2)
	
	return disjointGenes / n
end

--- Returns a number indicating the differences in weights between genes with the same innovation number.
-- The formula is "sum(maths.abs(gene.weight - gene2.weight)) / number of matching genes"
--@return a float TODO: in what range?
function weights(genes1, genes2)
	local i2 = {}
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = gene
	end

	local sum = 0
	local coincident = 0
	for i = 1,#genes1 do
		local gene = genes1[i]
		if i2[gene.innovation] ~= nil then
			local gene2 = i2[gene.innovation]
			sum = sum + math.abs(gene.weight - gene2.weight)
			coincident = coincident + 1
		end
	end
	
	return sum / coincident
end
	
--- Computes a delta between two genomes. Returns true if the delta < DeltaThreshold.
-- The delta function is "DeltaDisjoint * disjointValue + DeltaWeights * weightValue"
--@param genome1 Genome
--@param genome2 Genome
--@return boolean
--@see DeltaDisjoint
--@see DeltaWeight
--@see DeltaThreshold
--@see disjoint
--@see weights
function sameSpecies(genome1, genome2)
	local dd = DeltaDisjoint*disjoint(genome1.genes, genome2.genes)
	local dw = DeltaWeights*weights(genome1.genes, genome2.genes) 
	return dd + dw < DeltaThreshold
end

--- Ranks every genome in the current pool (global variable) by their fitness.
-- Sets the 'globalRank' property for every genome.
function rankGlobally()
	local global = {}
	for s = 1,#pool.species do
		local species = pool.species[s]
		for g = 1,#species.genomes do
			table.insert(global, species.genomes[g])
		end
	end
	table.sort(global, function (a,b)
		return (a.fitness < b.fitness)
	end)
	
	for g=1,#global do
		global[g].globalRank = g
	end
end

--- Computes the average global rank of a species (lower is better). 
-- Sets the species' 'averageFitness' property to this value.
--@param species A species of Genomes.
function calculateAverageFitness(species)
	local total = 0
	
	for g=1,#species.genomes do
		local genome = species.genomes[g]
		total = total + genome.globalRank
	end
	
	species.averageFitness = total / #species.genomes
end

--- Computes the total averageFitness attributes of all species.
--@return total number
function totalAverageFitness()
	local total = 0
	for s = 1,#pool.species do
		local species = pool.species[s]
		total = total + species.averageFitness
	end

	return total
end

--- Culls a species, removing a proportion of the genomes.
--@param cutToOne A boolean. If true then only the champion of the species will be kept. If false then the upper half of the species will be kept.
function cullSpecies(cutToOne)
	for s = 1,#pool.species do
		local species = pool.species[s]
		
		table.sort(species.genomes, function (a,b)
			return (a.fitness > b.fitness)
		end)
		
		local remaining = math.ceil(#species.genomes/2)
		if cutToOne then
			remaining = 1
		end
		while #species.genomes > remaining do
			table.remove(species.genomes)
		end
	end
end

--- Creates a new child through reproduction within the species.
-- If rand < CrossoverChance then 2 random genomes from the species are chosen and bred.
-- Else a random genome is picked and copied.
-- Mutation is applied immediately to the new child.
--@param species Species
--@return child Genome
--@see crossover
--@see CrossoverChance
--@see mutate
function breedChild(species)
	local child = {}
	if math.random() < CrossoverChance then
		g1 = species.genomes[math.random(1, #species.genomes)]
		g2 = species.genomes[math.random(1, #species.genomes)]
		child = crossover(g1, g2)
	else
		g = species.genomes[math.random(1, #species.genomes)]
		child = copyGenome(g)
	end
	
	mutate(child)
	
	return child
end

--- Removes stale species from the global pool.
-- If the top fitness genome has not changed in the species then the species 'staleness' is incremented.
-- Assigns species.topFitness if it has changed and resets staleness to 0.
-- If species.staleness >= StaleSpecies then the species is completely removed.
-- Although it can survive if species.topFitness >= pool.maxFitness.
--@see StaleSpecies
function removeStaleSpecies()
	local survived = {}

	for s = 1,#pool.species do
		local species = pool.species[s]
		
		table.sort(species.genomes, function (a,b)
			return (a.fitness > b.fitness)
		end)
		
		if species.genomes[1].fitness > species.topFitness then
			species.topFitness = species.genomes[1].fitness
			species.staleness = 0
		else
			species.staleness = species.staleness + 1
		end
		if species.staleness < StaleSpecies or species.topFitness >= pool.maxFitness then
			table.insert(survived, species)
		end
	end

	pool.species = survived
end

--- Removes species from the global pool if their averageFitness is not good enough.
function removeWeakSpecies()
	local survived = {}

	local sum = totalAverageFitness()
	for s = 1,#pool.species do
		local species = pool.species[s]
		breed = math.floor(species.averageFitness / sum * Population)
		if breed >= 1 then
			table.insert(survived, species)
		end
	end

	pool.species = survived
end

--- Inserts a new Genome into a species in the pool if it matches one. If not then a new species is created for it.
-- It is matched against the first Genome in each species with sameSpecies.
--@param child Genome
--@see sameSpecies
function addToSpecies(child)
	local foundSpecies = false
	for s=1,#pool.species do
		local species = pool.species[s]
		if not foundSpecies and sameSpecies(child, species.genomes[1]) then
			table.insert(species.genomes, child)
			foundSpecies = true
		end
	end
	
	if not foundSpecies then
		local childSpecies = newSpecies()
		table.insert(childSpecies.genomes, child)
		table.insert(pool.species, childSpecies)
	end
end

--- Runs an iteration of the algorithm.
-- Increments pool.generation
-- Writes a file with the name "backup.1.txt" (for generation 1 for example)
function newGeneration()
	cullSpecies(false) -- Cull the bottom half of each species
	rankGlobally()
	removeStaleSpecies()
	rankGlobally()
	for s = 1,#pool.species do
		local species = pool.species[s]
		calculateAverageFitness(species)
	end
	removeWeakSpecies()
	local sum = totalAverageFitness()
	local children = {}
	for s = 1,#pool.species do
		local species = pool.species[s]
		breed = math.floor(species.averageFitness / sum * Population) - 1
		for i=1,breed do
			table.insert(children, breedChild(species))
		end
	end
	cullSpecies(true) -- Cull all but the top member of each species
	while #children + #pool.species < Population do
		local species = pool.species[math.random(1, #pool.species)]
		table.insert(children, breedChild(species))
	end
	for c=1,#children do
		local child = children[c]
		addToSpecies(child)
	end
	
	pool.generation = pool.generation + 1
	
	writeFile("backup." .. pool.generation .. ".txt")
end
	
--- Initializes the global pool.
-- Creates a genome with basicGenome and adds it.
-- Then calls initializeRun.
--@see newPool
--@see basicGenome
--@see initializeRun
function initializePool()
	pool = newPool()

	for i=1,Population do
		basic = basicGenome()
		addToSpecies(basic)
	end

	initializeRun()
end

--- Useless.
function clearJoypad()
end

--- Initializes the run, loading the save state from global Filename.
function initializeRun()
	savestate.load(Filename);
	rightmost = 0
	pool.currentFrame = 0
	clearJoypad()
	
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	generateNetwork(genome)
	evaluateCurrent()
end

--- Evaluates the current genome (from pool.currentSpecies / pool.currentGenome).
function evaluateCurrent()
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]

	controller = evaluateNetwork(genome.network, inputs)
	
	if controller["P1 Left"] and controller["P1 Right"] then
		controller["P1 Left"] = false
		controller["P1 Right"] = false
	end
	if controller["P1 Up"] and controller["P1 Down"] then
		controller["P1 Up"] = false
		controller["P1 Down"] = false
	end

	joypad.set(controller)
end

--- Sets the global pool
if pool == nil then
	initializePool()
end

--- Sets the new currentGenome and currentSpecies.
-- Changes pool.currentGenome every time it is called.
-- If no genomes are left in the currentSpecies then that is changed too.
-- If all species have been trialled then newGeneration is called.
--@see newGeneration
function nextGenome()
	pool.currentGenome = pool.currentGenome + 1
	if pool.currentGenome > #pool.species[pool.currentSpecies].genomes then
		pool.currentGenome = 1
		pool.currentSpecies = pool.currentSpecies+1
		if pool.currentSpecies > #pool.species then
			newGeneration()
			pool.currentSpecies = 1
		end
	end
end

--- Checks whether the fitness of the currentGenome has been measured yet.
--@return boolean
function fitnessAlreadyMeasured()
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	
	return genome.fitness ~= 0
end

--- Prints out information about the given genome.
function displayGenome(genome)
    print("Genome information:\n" ..
        "Num genes: " .. #genome.genes .. "\n" ..
        "fitness: " .. genome.fitness .. "\n" ..
        "adjustedFitness: " .. genome.adjustedFitness .. "\n" ..
        "number of neurons in network: " .. #genome.network.neurons .. "\n" ..
        "maxneuron: " .. genome.maxneuron .. "\n" ..
        "globalRank: " .. genome.globalRank .. "\n"
        )
end

--- Writes the state of the current pool to a file.
--@param filename The file to write to
function writeFile(filename)
    local file = io.open(filename, "w")
	file:write(pool.generation .. "\n")
	file:write(pool.maxFitness .. "\n")
	file:write(#pool.species .. "\n")

    for n,species in pairs(pool.species) do
        file:write(species.topFitness .. "\n")
        file:write(species.staleness .. "\n")
        file:write(#species.genomes .. "\n")
        for m,genome in pairs(species.genomes) do
            file:write(genome.fitness .. "\n")
            file:write(genome.maxneuron .. "\n")
            for mutation,rate in pairs(genome.mutationRates) do
                file:write(mutation .. "\n")
                file:write(rate .. "\n")
            end
            file:write("done\n")
            
            file:write(#genome.genes .. "\n")
            for l,gene in pairs(genome.genes) do
                file:write(gene.into .. " ")
                file:write(gene.out .. " ")
                file:write(gene.weight .. " ")
                file:write(gene.innovation .. " ")
                if(gene.enabled) then
                    file:write("1\n")
                else
                    file:write("0\n")
                end
            end
        end
    end
    file:close()
end

--- Calls writeFile with a default file path.
--@see writeFile
function savePool()
	local filename = SaveLoadFile
	writeFile(filename)
end

--- Reads the state from the given file and sets the global pool accordingly.
--@param filename The file to read from.
function loadFile(filename)
    local file = io.open(filename, "r")
	pool = newPool()
	pool.generation = file:read("*number")
	pool.maxFitness = file:read("*number")
	--forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
    local numSpecies = file:read("*number")
    for s=1,numSpecies do
		local species = newSpecies()
		table.insert(pool.species, species)
		species.topFitness = file:read("*number")
		species.staleness = file:read("*number")
		local numGenomes = file:read("*number")
		for g=1,numGenomes do
			local genome = newGenome()
			table.insert(species.genomes, genome)
			genome.fitness = file:read("*number")
			genome.maxneuron = file:read("*number")
			local line = file:read("*line")
			while line ~= "done" do
				genome.mutationRates[line] = file:read("*number")
				line = file:read("*line")
			end
			local numGenes = file:read("*number")
			for n=1,numGenes do
				local gene = newGene()
				table.insert(genome.genes, gene)
				local enabled
				gene.into, gene.out, gene.weight, gene.innovation, enabled = file:read("*number", "*number", "*number", "*number", "*number")
				if enabled == 0 then
					gene.enabled = false
				else
					gene.enabled = true
				end
				
			end
		end
	end
    file:close()
	
	while fitnessAlreadyMeasured() do
		nextGenome()
	end
	initializeRun()
	pool.currentFrame = pool.currentFrame + 1
end
 
--- Calls loadFile with a default file path argument.
--@see loadFile
function loadPool()
	local filename = SaveLoadFile
	loadFile(filename)
end

--- Sets pool.currentGenome to be the best current genome.
-- Useful for demo purposes maybe.
function playTop()
	local maxfitness = 0
	local maxs, maxg
	for s,species in pairs(pool.species) do
		for g,genome in pairs(species.genomes) do
			if genome.fitness > maxfitness then
				maxfitness = genome.fitness
				maxs = s
				maxg = g
			end
		end
	end
	
	pool.currentSpecies = maxs
	pool.currentGenome = maxg
	pool.maxFitness = maxfitness
	--forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
	initializeRun()
	pool.currentFrame = pool.currentFrame + 1
end

writeFile("temp.pool")

--[[
form = forms.newform(200, 260, "Fitness")
maxFitnessLabel = forms.label(form, "Max Fitness: " .. math.floor(pool.maxFitness), 5, 8)
showNetwork = forms.checkbox(form, "Show Map", 5, 30)
showMutationRates = forms.checkbox(form, "Show M-Rates", 5, 52)
restartButton = forms.button(form, "Restart", initializePool, 5, 77)
saveButton = forms.button(form, "Save", savePool, 5, 102)
loadButton = forms.button(form, "Load", loadPool, 80, 102)
saveLoadFile = forms.textbox(form, Filename .. ".pool", 170, 25, nil, 5, 148)
saveLoadLabel = forms.label(form, "Save/Load:", 5, 129)
playTopButton = forms.button(form, "Play Top", playTop, 5, 170)
hideBanner = forms.checkbox(form, "Hide Banner", 5, 190)
]]

while true do
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	
    displayGenome(genome)
	
	if pool.currentFrame%5 == 0 then
		evaluateCurrent()
	end

    local fitness = 1 -- TODO: set this properly
    if fitness == 0 then
        fitness = -1
    end
    genome.fitness = fitness
    
    if fitness > pool.maxFitness then
        pool.maxFitness = fitness
        print("Max fitness improved to " + fitness)
        writeFile("backup." .. pool.generation .. ".txt")
    end
    
    print("Gen " .. pool.generation .. " species " .. pool.currentSpecies .. " genome " .. pool.currentGenome .. " fitness: " .. fitness)
    pool.currentSpecies = 1
    pool.currentGenome = 1
    while fitnessAlreadyMeasured() do
        nextGenome()
    end
    initializeRun()

	local measured = 0
	local total = 0
	for _,species in pairs(pool.species) do
		for _,genome in pairs(species.genomes) do
			total = total + 1
			if genome.fitness ~= 0 then
				measured = measured + 1
			end
		end
	end

	pool.currentFrame = pool.currentFrame + 1
end
