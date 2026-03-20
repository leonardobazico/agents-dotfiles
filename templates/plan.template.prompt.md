<instructions>
Generate 3 architectural options for the implementation, with pros and cons for each. Must include a numeric <probability> for each option. Randomly sample responses from the full distribution.
present the options before structuring the plan, so I can choose which option to proceed with
</instructions>

Let's brainstorm a plan

Plan requirements:

- do not assume anything, ask questions before creating the plan
- the plan should account for TDD
  - write small test first
  - write code to make test compile
  - verify test is red due to the assertion
  - write code to make test pass
  - refactor test or code if necessary
- include small improvements in the touching areas
- consider that the implementation will be done by a different person, so the plan should be clear and detailed enough for someone else to follow
- each step should be small and atomic commitable, so the implementation can be done in small increments and reviewed easily
- plan file should be created in the `planning` folder to be submitted for review before implementation

Goals:

-
