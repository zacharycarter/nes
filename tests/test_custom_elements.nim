import 
  unittest, jsffi, jsconsole, json, dom,
  nes

suite "Custom Elements":
  # https://developer.mozilla.org/en-US/docs/Web/Web_Components/Using_custom_elements#High-level_view
  test "custom element":
    class WordCount:
      parent: HTMLParagraphElement
      constructor:
        super()
    
    proc textContent(e: Element): cstring {.importcpp: "#.textContent".}
    customElements.define(cstring"word-count", WordCountConstructor, CustomElementOptions{extends: cstring"p"})
    
    require(
      document.querySelector("word-count").textContent == "Nim custom elements!"
    )