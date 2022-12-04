// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let nowSeconds = () => Math.round(Date.now() / 1000)
let rand = (min, max) => Math.floor(Math.random() * (max - min) + min)
let isVisible = (el) => !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length > 0)

let execJS = (selector, attr) => {
  document.querySelectorAll(selector).forEach(el => liveSocket.execJS(el, el.getAttribute(attr)))
}

let Hooks = {}

Hooks.Flash = {
  mounted(){
    let hide = () => liveSocket.execJS(this.el, this.el.getAttribute("phx-click"))
    this.timer = setTimeout(() => hide(), 8000)
    this.el.addEventListener("phx:hide-start", () => clearTimeout(this.timer))
    this.el.addEventListener("mouseover", () => {
      clearTimeout(this.timer)
      this.timer = setTimeout(() => hide(), 8000)
    })
  },
  destroyed(){ clearTimeout(this.timer) }
}
Hooks.AudioPlayer = {
  mounted(){
    this.playbackBeganAt = null
    this.player = this.el.querySelector("audio")
    this.currentTime = this.el.querySelector("#player-time")
    this.duration = this.el.querySelector("#player-duration")
    this.progress = this.el.querySelector("#player-progress")
    let enableAudio = () => {
      if(this.player.src){
        document.removeEventListener("click", enableAudio)
        if(this.player.readyState === 0){
          this.player.play().catch(error => null)
          this.player.pause()
        }
      }
    }
    document.addEventListener("click", enableAudio)
    this.el.addEventListener("js:listen_now", () => this.play({sync: true}))
    this.el.addEventListener("js:play_pause", () => {
      if(this.player.paused){
        this.play()
      }
    })
    this.handleEvent("play", ({url, token, elapsed, artist, title}) => {
      this.playbackBeganAt = nowSeconds() - elapsed
      let currentSrc = this.player.src.split("?")[0]
      if(currentSrc === url && this.player.paused){
        this.play({sync: true})
      } else if(currentSrc !== url) {
        this.player.src = `${url}?token=${token}`
        this.play({sync: true})
      }

      if("mediaSession" in navigator){
        navigator.mediaSession.metadata = new MediaMetadata({artist, title})
      }
    })
    this.handleEvent("pause", () => this.pause())
    this.handleEvent("stop", () => this.stop())
  },

  clearNextTimer(){
    clearTimeout(this.nextTimer)
    this.nextTimer = null
  },

  play(opts = {}){
    let {sync} = opts
    this.clearNextTimer()
    this.player.play().then(() => {
      if(sync){ this.player.currentTime = nowSeconds() - this.playbackBeganAt }
      this.progressTimer = setInterval(() => this.updateProgress(), 100)
    }, error => {
      if(error.name === "NotAllowedError"){
        execJS("#enable-audio", "data-js-show")
      }
    })
  },

  pause(){
    clearInterval(this.progressTimer)
    this.player.pause()
  },

  stop(){
    clearInterval(this.progressTimer)
    this.player.pause()
    this.player.currentTime = 0
    this.updateProgress()
    this.duration.innerText = ""
    this.currentTime.innerText = ""
  },

  updateProgress(){
    if(isNaN(this.player.duration)){ return false }
    if(!this.nextTimer && this.player.currentTime >= this.player.duration){
      clearInterval(this.progressTimer)
      this.nextTimer = setTimeout(() => this.pushEvent("next_song_auto"), rand(0, 1500))
      return
    }
    this.progress.style.width = `${(this.player.currentTime / (this.player.duration) * 100)}%`
    this.duration.innerText = this.formatTime(this.player.duration)
    this.currentTime.innerText = this.formatTime(this.player.currentTime)
  },

  formatTime(seconds){ return new Date(1000 * seconds).toISOString().substr(14, 5) }
}

Hooks.Ping = {
  mounted(){
    this.handleEvent("pong", () => {
      let rtt = Date.now() - this.nowMs
      this.el.innerText = `ping: ${rtt}ms`
      // this.timer = setTimeout(() => this.ping(rtt), 1000)
    })
    this.ping(null)
  },
  reconnected(){
    clearTimeout(this.timer)
    this.ping(null)
  },
  destroyed(){ clearTimeout(this.timer) },
  ping(rtt){
    this.nowMs = Date.now()
    this.pushEvent("ping", {rtt: rtt})
  }
}

// Accessible focus handling
let Focus = {
  focusMain(){
    let target = document.querySelector("main h1") || document.querySelector("main")
    if(target){
      let origTabIndex = target.tabIndex
      target.tabIndex = -1
      target.focus()
      target.tabIndex = origTabIndex
    }
  },
  // Subject to the W3C Software License at https://www.w3.org/Consortium/Legal/2015/copyright-software-and-document
  isFocusable(el){
    if(el.tabIndex > 0 || (el.tabIndex === 0 && el.getAttribute("tabIndex") !== null)){ return true }
    if(el.disabled){ return false }

    switch(el.nodeName) {
      case "A":
        return !!el.href && el.rel !== "ignore"
      case "INPUT":
        return el.type != "hidden" && el.type !== "file"
      case "BUTTON":
      case "SELECT":
      case "TEXTAREA":
        return true
      default:
        return false
    }
  },
  // Subject to the W3C Software License at https://www.w3.org/Consortium/Legal/2015/copyright-software-and-document
  attemptFocus(el){
    if(!el){ return }
    if(!this.isFocusable(el)){ return false }
    try {
      el.focus()
    } catch(e){}

    return document.activeElement === el
  },
  // Subject to the W3C Software License at https://www.w3.org/Consortium/Legal/2015/copyright-software-and-document
  focusFirstDescendant(el){
    for(let i = 0; i < el.childNodes.length; i++){
      let child = el.childNodes[i]
      if(this.attemptFocus(child) || this.focusFirstDescendant(child)){
        return true
      }
    }
    return false
  },
  // Subject to the W3C Software License at https://www.w3.org/Consortium/Legal/2015/copyright-software-and-document
  focusLastDescendant(element){
    for(let i = element.childNodes.length - 1; i >= 0; i--){
      let child = element.childNodes[i]
      if(this.attemptFocus(child) || this.focusLastDescendant(child)){
        return true
      }
    }
    return false
  },
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: {_csrf_token: csrfToken},
  dom: {
    onNodeAdded(node){
      if(node instanceof HTMLElement && node.autofocus){
        node.focus()
      }
    }
  }
})

let routeUpdated = () => {
  Focus.focusMain()
}

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "rgba(147, 51, 234, 1)"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// Accessible routing
window.addEventListener("phx:page-loading-stop", routeUpdated)

window.addEventListener("js:exec", e => e.target[e.detail.call](...e.detail.args))
window.addEventListener("js:focus", e => {
  let parent = document.querySelector(e.detail.parent)
  if(parent && isVisible(parent)){ e.target.focus() }
})
window.addEventListener("js:focus-closest", e => {
  let el = e.target
  let sibling = el.nextElementSibling
  while(sibling){
    if(isVisible(sibling) && Focus.attemptFocus(sibling)){ return }
    sibling = sibling.nextElementSibling
  }
  sibling = el.previousElementSibling
  while(sibling){
    if(isVisible(sibling) && Focus.attemptFocus(sibling)){ return }
    sibling = sibling.previousElementSibling
  }
  Focus.attemptFocus(el.parent) || Focus.focusMain()
})
window.addEventListener("phx:remove-el", e => document.getElementById(e.detail.id).remove())

// connect if there are any LiveViews on the page
liveSocket.getSocket().onOpen(() => execJS("#connection-status", "js-hide"))
liveSocket.getSocket().onError(() => execJS("#connection-status", "js-show"))
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

