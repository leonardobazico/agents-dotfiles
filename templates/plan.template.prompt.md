let's brainstorm towards the following goals:

-
-

Requirements:

- do not assume anything, ask questions before creating the plan
- the plan should account for TDD
  - write small test first
  - write code to make test compile
  - verify test is red due to the assertion
  - write code to make test pass
- each commit should be rely on pre-commit checks to ensure quality and correctness
- consider that the implementation will be done by someone else, the plan should be concise for them to follow without ambiguity
- target audience is code harness agents, so not need to keep it human friendly, drop articles, fragments OK, short synonyms, be brief.
- include small improvements in the touching areas
- the implementation should be done in small increments and reviewed by human in the loop