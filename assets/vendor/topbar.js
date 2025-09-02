/**
 * @license MIT
 * topbar 1.0.0, 2021-01-06
 * https://buunguyen.github.io/topbar
 * Copyright (c) 2021 Buu Nguyen
 */

const topbar = (function() {
  "use strict";

  let canvas,
    progressTimerId = null,
    fadeTimerId = null,
    currentProgress,
    showing;

  const options = {
    autoRun: true,
    barThickness: 3,
    barColors: {
      0: "rgba(26,  188, 156, .9)",
      ".25": "rgba(52,  152, 219, .9)",
      ".50": "rgba(241, 196, 15,  .9)",
      ".75": "rgba(230, 126, 34,  .9)",
      "1.0": "rgba(211, 84,  0,   .9)",
    },
    shadowBlur: 10,
    shadowColor: "rgba(0,   0,   0,   .6)",
    className: null,
  };

  function addEvent(elem, type, handler) {
    if (elem.addEventListener) elem.addEventListener(type, handler, false);
    else if (elem.attachEvent) elem.attachEvent("on" + type, handler);
    else elem["on" + type] = handler;
  }

  function repaint() {
    canvas.width = window.innerWidth;
    canvas.height = options.barThickness * 5;

    const ctx = canvas.getContext("2d");
    ctx.shadowBlur = options.shadowBlur;
    ctx.shadowColor = options.shadowColor;

    const lineGradient = ctx.createLinearGradient(0, 0, canvas.width, 0);
    for (const stop in options.barColors)
      lineGradient.addColorStop(stop, options.barColors[stop]);
    
    ctx.lineWidth = options.barThickness;
    ctx.beginPath();
    ctx.moveTo(0, options.barThickness / 2);
    ctx.lineTo(
      Math.ceil(currentProgress * canvas.width),
      options.barThickness / 2
    );
    ctx.strokeStyle = lineGradient;
    ctx.stroke();
  }

  function createCanvas() {
    canvas = document.createElement("canvas");
    const style = canvas.style;
    style.position = "fixed";
    style.top = style.left = style.right = style.margin = style.padding = 0;
    style.zIndex = 100001;
    style.display = "none";
    if (options.className) canvas.className = options.className;
    document.body.appendChild(canvas);
    addEvent(window, "resize", repaint);
  }

  return {
    config: function (opts) {
      for (const key in opts)
        if (options.hasOwnProperty(key)) options[key] = opts[key];
    },

    show: function () {
      if (showing) return;
      showing = true;
      if (fadeTimerId !== null) cancelAnimationFrame(fadeTimerId);
      if (!canvas) createCanvas();
      canvas.style.opacity = 1;
      canvas.style.display = "block";
      this.progress(0);
      
      if (options.autoRun) {
        var self = this;
        (function loop() {
          progressTimerId = requestAnimationFrame(loop);
          self.progress(
            "+" + 0.05 * Math.pow(1 - Math.sqrt(currentProgress), 2)
          );
        })();
      }
    },

    progress: function (to) {
      if (typeof to === "undefined") return currentProgress;
      if (typeof to === "string") {
        to =
          (to.indexOf("+") >= 0 || to.indexOf("-") >= 0
            ? currentProgress
            : 0) + parseFloat(to);
      }
      currentProgress = to > 1 ? 1 : to;
      repaint();
      return currentProgress;
    },

    hide: function () {
      if (!showing) return;
      showing = false;
      if (progressTimerId != null) {
        cancelAnimationFrame(progressTimerId);
        progressTimerId = null;
      }
      
      var self = this;
      (function loop() {
        if (self.progress("+.1") >= 1) {
          canvas.style.opacity -= 0.05;
          if (canvas.style.opacity <= 0.05) {
            canvas.style.display = "none";
            fadeTimerId = null;
            return;
          }
        }
        fadeTimerId = requestAnimationFrame(loop);
      })();
    },
  };
})();

export default topbar;