# TGenetics: the evolution loop, as a service

**Genetic algorithms as a service.** You define a chromosome, we run the loop: we suggest an organism to test → you test it on your own infrastructure and report ONE fitness number → we breed the next generation worth exploring → repeat.

**We never run or evaluate your fitness function.** The customer owns their evaluation infrastructure and compute; we operate the evolution (population, generations, breeding, history). The only fitness-bearing input is the customer-reported number. See THESIS.md for the full contract.

This application provides a framework for exploring and utilizing genetic algorithms and evolutionary computation.

## Core Functionality

The system is designed to:

*   **Define Genetic Structures:** Users can define `Chromosome`s, which are composed of `Allele`s. Alleles can be of various types, including:
    *   `Float` (representing a range of floating-point numbers)
    *   `Integer` (representing a range of integers)
    *   `Boolean` (representing true/false values)
    *   `Option` (representing a selection from a predefined list of choices)

    Example of creating alleles:
    ```ruby
    chromosome = Chromosome.create(name: 'My Chromosome')

    # Integer Allele
    chromosome.alleles << Allele.new_with_integer(name: 'gene_int', minimum: 0, maximum: 100)

    # Float Allele
    chromosome.alleles << Allele.new_with_float(name: 'gene_float', minimum: 0.0, maximum: 1.0)

    # Boolean Allele
    chromosome.alleles << Allele.new_with_boolean(name: 'gene_bool')

    # Option Allele
    chromosome.alleles << Allele.new_with_option(name: 'gene_option', choices: ['A', 'B', 'C'])
    ```

*   **Manage Populations:** The application supports the creation and management of `Generation`s, which are collections of `Organism`s. Each organism possesses a set of `Value`s corresponding to the alleles in its chromosome.
*   **Simulate Evolution:** Key evolutionary operations are implemented as commands, allowing for:
    *   **Fitness aggregation:** Computing aggregate fitness statistics (total, average) from reported fitness values within a generation — never running the customer's fitness function itself.
    *   **Selection:** Picking organisms for reproduction based on fitness or other criteria (`Generations::Pick`).
    *   **Reproduction:**
        *   `Cloning`: Creating identical copies of organisms.
        *   `Crossover`: Combining genetic material from parent organisms to create offspring.
        *   `Procreation`: A higher-level command that orchestrates the creation of new organisms from parents, often involving crossover and mutation.
    *   **Mutation:** Introducing random changes to an organism's genetic material (`Organism#mutate!`).
*   **Data Output:** The `WriteTrainingFiles` command suggests functionality to export genetic data, potentially for use in training external machine learning models or other analytical processes.
*   **Web Interface:** A web interface (built with Ruby on Rails) allows for the management and inspection of `Chromosome`s and `Allele`s.

## Getting Started

(This section would typically include instructions on setting up the development environment, such as Ruby version, system dependencies, database setup, etc.)

*   Ruby version: (Specify from `.ruby-version`)
*   System dependencies: (List any)
*   Configuration: (Details on `config/database.yml`, etc.)
*   Database creation: `rails db:create`
*   Database initialization: `rails db:schema:load` (or `rails db:setup` which includes seeds)
*   How to run the test suite: `bundle exec rspec`

### API Documentation (OpenAPI / Swagger)
- Swagger UI: `http://localhost:3001/api-docs` (development/test only)
- Generated OpenAPI artifact (committed): `swagger/v1/swagger.yaml`
- Regenerate the artifact:
  - `bundle exec rake rswag:specs:swaggerize`
- Verify the committed artifact is up to date (CI-friendly):
  - `bundle exec rake rswag:verify`

## Key Components

*   **Models (`app/models`):** Define the core data structures like `Chromosome`, `Allele`, `Generation`, `Organism`, and `Value`. Different allele types (`Alleles::Float`, `Alleles::Integer`, etc.) and their corresponding value types (`Values::Float`, `Values::Integer`, etc.) are implemented using polymorphic associations with specific backing tables.
*   **Model Concerns (`app/models/concerns`):** Contain shared functionality mixed into models. Key examples include `Inheritable` (for different allele types) and `Valuable` (for different value types associated with alleles).
*   **Commands (`app/commands`):** Encapsulate business logic for evolutionary operations and other discrete actions (e.g., `Generations::Fitness`, `Organisms::Procreate`, `Organisms::Crossover`). These follow the `gl_command` pattern for callable service objects.
*   **Controllers (`app/controllers`):** Handle web requests, focusing on authentication, input validation, calling appropriate commands, and rendering responses. They primarily manage `Chromosome`s and `Allele`s through the UI.
*   **Views (`app/views`):** Standard Rails views that provide the HTML structure for the user interface.
*   **ViewComponents (`app/components`):** Reusable UI elements (e.g., `ChromosomeComponent`, `PageheaderComponent`) used to build the views, promoting modularity and testability in the frontend layer.
*   **Packs (`packs/`):** Domain-specific code is organized into packs.
    *   **Experiments (`packs/experiments`):** This pack introduces the concept of an `Experiment`, which formalizes an evolutionary run. An `Experiment` links a specific `Chromosome` to an `external_entity` (e.g., a project or task in the wider application) and manages its evolutionary lifecycle. Key aspects include:
        *   **`Experiment` Model:** Tracks the configuration (like `population_size`), status (pending, running, completed, failed), and the `current_generation` of organisms. It also holds criteria for automated evolution, such as feedback thresholds.
        *   **`PerformanceLog` Model:** Records each instance an `Organism` from an experiment is "suggested" for use by the `external_entity`. Later, the outcome of this suggestion (e.g., a `fitness_input_value` and other `outcome_metrics`) can be recorded on this log.
        *   **Automated Evolution Cycle:**
            *   `Experiments::RequestSuggestion`: Selects an organism from the experiment's current generation to be "used" (e.g., by the `external_entity`), creating a `PerformanceLog`.
            *   `Experiments::RecordOutcome`: Updates the `PerformanceLog` with the results of using the organism, including a `fitness_input_value`.
            *   `Experiments::EvaluateAndEvolve`: When an experiment is deemed `ripe_for_evolution?` (based on criteria like the amount of feedback received or the number of suggestions made), this command evaluates the fitness of organisms in the current generation (using their `PerformanceLog` data) and then creates a new generation of organisms.
        *   `Experiments::Setup`: Initializes a new `Experiment` with its first generation of organisms.
*   **Database Migrations (`db/migrate`):** Define and manage changes to the database schema over time.
*   **Tests (`spec/`):** Automated tests to ensure code quality and correctness. This includes unit tests for models and commands, request specs for controller actions and authentication, and potentially integration specs for critical flows, as outlined in `CONVENTIONS.md`.

## Genetic Algorithm Process

The application implements a genetic algorithm with the following key steps:

1.  **Initialization (`Organisms::Create`)**:
    *   When an `Organism` is created, it is associated with a `Generation` and its `Chromosome`.
    *   For each `Allele` in the `Chromosome`, a corresponding `Value` instance is created.
    *   The `Value.new_from(allele)` method initializes the specific `valuable` type (e.g., `Values::Float`, `Values::Integer`), which then assigns an initial `data` value, typically randomly within the allele's defined constraints (e.g., min/max for numbers, a random choice for options).

2.  **Fitness Evaluation (`Generations::Fitness`, `Organism#fitness` attribute)**:
    *   Each `Organism` has a `fitness` attribute that stores its evaluated fitness score.
    *   The `Generations::Fitness` command calculates aggregate fitness metrics, such as total and average fitness, for all organisms within a `Generation`.
    *   Fitness scores are typically assigned to organisms externally and then updated (e.g., via `organism.update(fitness: ...)`).

3.  **Selection (`Generations::Pick`)**:
    *   The `Generations::Pick` command selects an organism from a parent `Generation` to act as a parent.
    *   It uses a fitness proportionate selection method (roulette wheel selection):
        *   The total fitness of the parent generation is calculated.
        *   A random selection point is chosen based on this total fitness.
        *   Organisms are iterated, and their fitness values are cumulatively summed. The organism whose cumulative fitness contribution causes the sum to exceed the random selection point is chosen.

4.  **Crossover (`Organisms::Procreate` calling `Organisms::Crossover`)**:
    *   The `Organisms::Procreate` command orchestrates reproduction:
        1.  It takes two selected `parents`.
        2.  It creates `children` by initially cloning each parent using `parent.dolly_clone`. These children start as exact copies.
        3.  It then invokes `Organisms::Crossover.call!(organisms: context.children)` to perform genetic crossover on these cloned children.
    *   The `Organisms::Crossover` command:
        1.  Iterates through the alleles of the first child's chromosome.
        2.  For each allele, it gathers the corresponding `Value` instances from all children involved in the crossover.
        3.  It calls the `allele.crossover_algorithm` (e.g., `Organisms::Crossovers::Average` or `Organisms::Crossovers::Random`) with these values.
        4.  The specific crossover algorithm (e.g., `Average`) then modifies the `data` of these allele values directly on the children. For instance, `Organisms::Crossovers::Average` would set the allele's value on both children to be the average of their (initially cloned) parental values for that allele.

5.  **Mutation (`Organisms::Procreate` calling `Organism#mutate!`)**:
    *   Following crossover, `Organisms::Procreate` calls the `mutate!` method on each child.
    *   `Organism#mutate!` iterates through all `Value` instances of the organism.
    *   Each `Value` has a probability (defined by `MUTATION_RATE`) of being mutated.
    *   If selected for mutation, `value.mutate!` is called, which sets the `data` of the underlying `valuable` object to a new random value, appropriate for the allele's type and constraints.

6.  **Replacement/Next Generation (`Generations::New`)**:
    *   The `Generations::New` command is responsible for creating a new `offspring_generation`.
    *   It repeatedly performs the selection and procreation (cloning, crossover, mutation) sequence:
        *   Picks parent organisms from the `parent_generation`.
        *   Calls `Organisms::Procreate` to generate children from these parents.
        *   Assigns these newly created children to the `offspring_generation`.
    *   This process continues until the `offspring_generation` reaches its target `organism_count`. This implements a generational replacement strategy.

## Further Development

(This section could outline potential future enhancements or areas of focus.)
