/* =========================================================================
   RoomForge Motion Layer
   Dependency-free micro-interactions shared across mockups:
   - reveal-on-scroll (IntersectionObserver)
   - staggered children
   - button/tap ripples
   - segmented-control sliding thumb
   - toast helper (window.rfToast)
   All effects honor prefers-reduced-motion.
   ========================================================================= */
(function () {
  "use strict";

  var reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---- Reveal on scroll ------------------------------------------------ */
  function initReveal() {
    var nodes = document.querySelectorAll("[data-reveal], [data-stagger]");
    if (reduced || !("IntersectionObserver" in window)) {
      nodes.forEach(function (n) { n.classList.add("is-in"); });
      return;
    }
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (!e.isIntersecting) return;
        var el = e.target;
        var delay = parseInt(el.getAttribute("data-delay") || "0", 10);
        setTimeout(function () { el.classList.add("is-in"); }, delay);
        // stagger children
        if (el.hasAttribute("data-stagger")) {
          Array.prototype.forEach.call(el.children, function (child, i) {
            child.style.transitionDelay = (i * 55) + "ms";
          });
        }
        io.unobserve(el);
      });
    }, { threshold: 0.12, rootMargin: "0px 0px -8% 0px" });
    nodes.forEach(function (n) { io.observe(n); });
  }

  /* ---- Ripple on press ------------------------------------------------- */
  function initRipple() {
    if (reduced) return;
    document.addEventListener("pointerdown", function (ev) {
      var target = ev.target.closest(".rf-btn, .rf-icon-btn, [data-ripple]");
      if (!target) return;
      var rect = target.getBoundingClientRect();
      var size = Math.max(rect.width, rect.height);
      var span = document.createElement("span");
      span.className = "rf-ripple";
      span.style.width = span.style.height = size + "px";
      span.style.left = (ev.clientX - rect.left - size / 2) + "px";
      span.style.top = (ev.clientY - rect.top - size / 2) + "px";
      target.appendChild(span);
      setTimeout(function () { span.remove(); }, 600);
    });
  }

  /* ---- Segmented control ---------------------------------------------- */
  function moveThumb(seg, btn) {
    var thumb = seg.querySelector(".thumb");
    if (!thumb) return;
    thumb.style.width = btn.offsetWidth + "px";
    thumb.style.transform = "translateX(" + (btn.offsetLeft - 3) + "px)";
  }
  function initSegments() {
    document.querySelectorAll(".rf-segment").forEach(function (seg) {
      var btns = seg.querySelectorAll("button");
      var selected = seg.querySelector('button[aria-selected="true"]') || btns[0];
      requestAnimationFrame(function () { moveThumb(seg, selected); });
      btns.forEach(function (btn) {
        btn.addEventListener("click", function () {
          btns.forEach(function (b) { b.setAttribute("aria-selected", "false"); });
          btn.setAttribute("aria-selected", "true");
          moveThumb(seg, btn);
          var ev = new CustomEvent("rf:segment", { detail: { value: btn.dataset.value || btn.textContent } });
          seg.dispatchEvent(ev);
        });
      });
      window.addEventListener("resize", function () {
        moveThumb(seg, seg.querySelector('button[aria-selected="true"]') || btns[0]);
      });
    });
  }

  /* ---- Toast ----------------------------------------------------------- */
  window.rfToast = function (message, opts) {
    opts = opts || {};
    var region = document.querySelector(".rf-toast-region");
    if (!region) {
      region = document.createElement("div");
      region.className = "rf-toast-region";
      region.setAttribute("role", "status");
      region.setAttribute("aria-live", "polite");
      document.body.appendChild(region);
    }
    var t = document.createElement("div");
    t.className = "rf-toast";
    t.textContent = message;
    region.appendChild(t);
    setTimeout(function () {
      t.style.transition = "opacity 240ms, transform 240ms";
      t.style.opacity = "0";
      t.style.transform = "translateY(8px)";
      setTimeout(function () { t.remove(); }, 260);
    }, opts.duration || 2600);
  };

  /* ---- Animate numeric progress bars to their data-value -------------- */
  function initProgress() {
    document.querySelectorAll(".rf-progress > span[data-value]").forEach(function (s) {
      var v = s.getAttribute("data-value");
      s.style.width = "0%";
      requestAnimationFrame(function () {
        setTimeout(function () { s.style.width = v + "%"; }, 120);
      });
    });
  }

  function boot() {
    initReveal();
    initRipple();
    initSegments();
    initProgress();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
