const puppeteer = require("puppeteer")
const path = require("path")

module.exports = (async() => {
  const browser = await puppeteer.launch()
  const page = await browser.newPage()

  page.on("console", msg => {
    const text = msg.text()

    if (text.indexOf("[OK]") > -1) {
      console.log("\x1b[32m%s\x1b[0m", text)
    } else if (text.indexOf("[Suite]") > -1 && text.indexOf("[FAILED]") == -1) {
      console.log("\x1b[36m%s\x1b[0m", text)
    } else{
      console.log("\x1b[31m%s\x1b[0m", text)
    }
  })

  try {
    await page.goto(`file://${path.join(__dirname, "index.html")}`)
    await page.goto(`file://${path.join(__dirname, "index.1.html")}`)
    await browser.close()
  } catch(e) {
    console.error("Error executing unit tests via puppeteer: " + e.message)
  }
})()