import macros

dumpAstGen:
  type
    Foo = object
      currentWorkflowStep* {.exportc.}: `WorkflowStep`