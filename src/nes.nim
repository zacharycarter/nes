import 
  macros, jsconsole, jsffi, strutils, strscans, sequtils, #stdlib
  litz, # internal
  ast_pattern_matching # 3rdparty

export litz

type
  ES2015Class* = ref object of JsObject

  CustomElementOptions* = ref object of JsObject
    extends*: cstring

  CustomElementRegistry {.importc.} = ref object of JsObject

var 
  customElements* {.nodecl, importc.}: CustomElementRegistry

proc define*(cer: CustomElementRegistry, n: cstring, c: JsObject, o: CustomElementOptions = nil) {.importcpp: "#.define(@)".}

macro class*(arg1, arg2: untyped): untyped =
  # echo treeRepr arg1, treeRepr arg2
  
  var 
    baseClassNameNode, parentClassNameNode: NimNode
    baseClassName, parentClassName: string
    exportClass = false
  
  arg1.matchAst(matchErrors):
  of `name` @ nnkIdent:
    baseClassNameNode = name
    baseClassName = $baseClassNameNode
  of nnkCall(
    `name`,
    `parentName`
  ):
    baseClassNameNode = name
    baseClassName = $baseClassNameNode
    parentClassNameNode = parentName
    parentClassName = $parentClassNameNode
  of nnkInfix(
    ident"*",
    `name`,
    nnkPar
  ):
    baseClassNameNode = name
    baseClassName = $baseClassNameNode
    exportClass = true
  of nnkInfix(
    ident"*",
    `name`,
    nnkPar(
      `parentName`
    )
  ):
    baseClassNameNode = name
    baseClassName = $baseClassNameNode
    parentClassNameNode = parentName
    parentClassName = $parentClassNameNode
    exportClass = true
  else:
    echo matchErrors

  var 
    jsConstructorParams: seq[string] = @[]
    jsConstructorBody: string
    jsTemplates: seq[string] = @[]
    nimConstructorParams = nnkFormalParams.newTree(baseClassNameNode)
    objectProperties = nnkRecList.newTree()
    templateProperties: seq[tuple[name: NimNode, val: NimNode]] = @[]
    observableProperties: seq[
      tuple[
        name: NimNode,
        kind: NimNode,
        initialValue: NimNode
      ]
    ] = @[]
    protoMethods: seq[
      tuple[
        protoMethodNameNode: NimNode,
        protoMethodParamsNode: NimNode,
        protoMethodBodyNode: NimNode,
      ]
    ] = @[]
  
  for arg in arg2:
    arg.matchAst(matchErrors):
    of nnkCall(
      ident"constructorBody",
      `constructorBody` @ nnkStmtList
    ):
      jsConstructorBody = $toStrLit(constructorBody)
    of nnkCall(
      `propName`,
      nnkStmtList(
        nnkAsgn(
          nnkPragmaExpr(
            `propKind`,
            `pragmas`
          ),
          `initialValue`
        )
      )
    ):
      if len(pragmas) > 0 and 
        pragmas.findChild(
          it.kind == nnkIdent and $it == "observable"
        ) != nil:
        observableProperties.add((propName, propKind, initialValue))
        objectProperties.add(
          if len(pragmas) > 1 and 
            pragmas[1].kind == nnkIdent and 
            $(pragmas[1]) == "exported":
            nnkIdentDefs.newTree(
              nnkPragmaExpr.newTree(
                nnkPostfix.newTree(
                  ident"*",
                  propName
                ),
                nnkPragma.newTree(
                  newIdentNode("exportc")
                ),
              ),
              propKind,
              newEmptyNode()
            )
          else:
            nnkIdentDefs.newTree(
              propName,
              propKind,
              newEmptyNode()
            )
        )
    of nnkCall(
      `propName`,
      nnkStmtList(
        `propType`
      )
    ):
      var propertyName: string = $propName
      if propType.kind == nnkIdent or propType.kind == nnkBracketExpr:
        nimConstructorParams.add(
          nnkIdentDefs.newTree(
            propName,
            propType,
            newEmptyNode()
          )
        )
      
      if propType.kind == nnkIdent:
        objectProperties.add(
          nnkIdentDefs.newTree(
            propName,
            propType,
            newEmptyNode()
          )
        )
        jsConstructorParams.add($propertyName)
      elif propType.kind == nnkBracketExpr and
        len(propType) > 0 and propType[0] == ident"varargs":
        propertyName = "..." & propertyName
        jsConstructorParams.add($propertyName)

    of nnkAsgn(
      `templateVarName`,
      nnkCall(
        ident"html_templ",
        `templateBody`
      )
    ):
      templateProperties.add(
        (
          templateVarName, 
          if len(templateBody) > 0 and templateBody[0].kind == nnkAccQuoted:
            ident(
              toSeq(templateBody[0].children).map(
                proc(bodyNode: NimNode): string =
                  $bodyNode
              ).join("").strip()
            )
          else:
            templateBody
        )
      )

      jsTemplates.add(
        $templateVarName
      )
    of nnkAsgn(
      `protoMethodName`,
      nnkLambda(
        _,
        _,
        _,
        `protoMethodParams` @ nnkFormalParams,
        _,
        _,
        `protoMethodBody`
      )
    ):
      protoMethods.add(
        (
          protoMethodName,
          protoMethodParams,
          protoMethodBody
        )
      )
    else:
      echo matchErrors

  result = newStmtList(
    nnkTypeSection.newTree(
      nnkTypeDef.newTree(
        if exportClass: 
          nnkPostfix.newTree(
            newIdentNode("*"),
            baseClassNameNode
          )
        else:
          baseClassNameNode,
        newEmptyNode(),
        nnkRefTy.newTree(
          nnkObjectTy.newTree(
            newEmptyNode(),
            nnkOfInherit.newTree(
              if parentClassNameNode != nil: parentClassNameNode else: ident"ES2015Class"
            ),
            objectProperties
          )
        )
      )
    ),
    nnkProcDef.newTree(
      ident("new" & baseClassName),
      newEmptyNode(),
      newEmptyNode(),
      nimConstructorParams,
      nnkPragma.newTree(
        nnkExprColonExpr.newTree(
          newIdentNode("importcpp"),
          if len(jsConstructorParams) == 1: 
            newLit("new " & baseClassName & "(#)") 
          elif len(jsConstructorParams) > 1:
            newLit("new " & baseClassName & "(@)")
          else: 
            newLit("new " & baseClassName & "()")
        )
      ),
      newEmptyNode(),
      newEmptyNode()
    ),
    nnkVarSection.newTree(
      nnkIdentDefs.newTree(
        nnkPragmaExpr.newTree(
          ident(baseClassName & "Constructor"),
          nnkPragma.newTree(
            nnkExprColonExpr.newTree(
              ident"importc",
              newLit(baseClassName)
            ),
            newIdentNode("nodecl")
          )
        ),
        ident"JsObject",
        newEmptyNode()
      )
    )
  )

  for protoMethod in protoMethods:
    result.add(
      nnkProcDef.newTree(
        protoMethod.protoMethodNameNode,
        newEmptyNode(),
        newEmptyNode(),
        protoMethod.protoMethodParamsNode,
        nnkPragma.newTree(
          nnkExprColonExpr.newTree(
            newIdentNode("importcpp"),
            newLit("#." & $(protoMethod.protoMethodNameNode) & "()")
          )
        ),
        newEmptyNode(),
        newEmptyNode()
      )
    )

  for templateProp in templateProperties:
    result.add(html_templ(result, templateProp.name, templateProp.val))

  var jsClass = "class " & baseClassName
  if len(parentClassName) > 0:
    jsClass &= " extends " & parentClassName
  
  jsClass &= """ {
    $1
    constructor($2) {
      $3
      $4
      $5
      $6
    }
  """.unindent() % [
    observableProperties.map(
      proc(observableProperty: tuple[name: NimNode, kind: NimNode, initialValue: NimNode]): string =
        result = "@observable " & $(observableProperty.name) & " = " & $(toStrLit(observableProperty.initialValue)) & ";"
    ).join("\n"),
    jsConstructorParams.join(", "),
    if len(parentClassName) > 0: "super($1);" % jsConstructorParams.join(", ") else: "",
    jsConstructorParams.map(
      proc(paramName: string): string =
        if not paramName.startsWith("..."):
          "this." & paramName & " = " & paramName & ";"
        else:
          ""
    ).join("\n"),
    jsTemplates.map(
      proc(templateName: string): string =
        "this." & templateName & " = " & templateName & ";"
    ).join("\n"),
    toSeq(jsConstructorBody.splitLines).map(
      proc(bs: string): string = 
        if len(bs) > 0: 
          bs & ";" 
        else: ""
    ).join("\n")
  ]
  
  for protoMethod in protoMethods:
    var 
      protoMethodName = $(protoMethod.protoMethodNameNode)
      protoMethodObjectParamName = $(protoMethod.protoMethodParamsNode[1][0])
      protoMethodBody = ""
    
    for childBodyNode in protoMethod.protoMethodBodyNode:
      childBodyNode.matchAst(matchErrors):
      of nnkAsgn(
        ident"result",
        `call`
      ):
        protoMethodBody &= "return " & ($toStrLit(call)).multiReplace(
          [
            (", " & protoMethodObjectParamName, ", this"),
            (protoMethodObjectParamName & ".", "this."),
            (protoMethodObjectParamName & ",", "this,")
          ]
        ) & ";\n"
      of nnkAsgn(
        `leftHandSide` @ nnkDotExpr,
        nnkCall(
          `callName` @ nnkIdent,
          nnkLambda(
            _,
            _,
            _,
            nnkFormalParams,
            _,
            _,
            `lambdaBody` @ nnkStmtList
          )
        )
      ):
        protoMethodBody &= (
          ($toStrLit(leftHandSide) & " = $1(() => { $2;\n });") % 
            [
              $callName,
              $(
                toSeq(lambdaBody.children).map(
                  proc(lbc: NimNode): string = $toStrLit(lbc)
                ).join(";\n")
              )
            ]
        ).multiReplace(
          [
            ("(" & protoMethodObjectParamName & ")", "(this)"),
            (", " & protoMethodObjectParamName, ", this"),
            (protoMethodObjectParamName & ".", "this."),
            (protoMethodObjectParamName & ",", "this,")
          ]
        ) & ";\n"
      of `assignment` @ nnkAsgn(
        nnkDotExpr,
        nnkCall
      ):
        protoMethodBody &= ($toStrLit(assignment)).multiReplace(
          [
            ("(" & protoMethodObjectParamName & ")", "(this)"),
            (", " & protoMethodObjectParamName, ", this"),
            (protoMethodObjectParamName & ".", "this."),
            (protoMethodObjectParamName & ",", "this,")
          ]
        ) & ";\n"
      of nnkCall(
        `callName`,
        nnkLambda(
          _,
          _,
          _,
          nnkFormalParams,
          _,
          _,
          `lambdaBody`
        )
      ):
        protoMethodBody &= (
          ($toStrLit(callName) & "(() => { $1;\n });") % 
            $(toSeq(lambdaBody.children).map(
              proc(lbc: NimNode): string = $toStrLit(lbc)
            ).join(";\n"))).multiReplace(
              [
                ("(" & protoMethodObjectParamName & ")", "(this)"),
                (", " & protoMethodObjectParamName, ", this"),
                (protoMethodObjectParamName & ".", "this."),
                (protoMethodObjectParamName & ",", "this,")
              ]
            ) & ";\n"
      of `call` @ nnkCall:
        protoMethodBody &= ($toStrLit(call)).multiReplace(
          [
            (", " & protoMethodObjectParamName, ", this"),
            (protoMethodObjectParamName & ".", "this."),
            (protoMethodObjectParamName & ",", "this,")
          ]
        ) & ";\n"
      else:
        echo matchErrors
    
    jsClass &=
      """
      $1() {
        $2
      }
      """.unindent() % [
          protoMethodName,
          protoMethodBody
        ]
  
  jsClass &= "};"
  
  result.add(
    quote do:
      {.emit: `jsClass`.}
  )
  
  # echo repr result