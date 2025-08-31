// Political Live Feed JavaScript Enhancements

export const PoliticalLive = {
  mounted() {
    this.initializeLiveEffects();
    this.setupAutoScroll();
    
    // Add glitch effect to live indicators
    this.addGlitchEffect();
    
    // Simulate typing effect for new articles
    this.addTypingEffect();
    
    // Add ticker-style news updates
    this.startNewsTickerEffect();
  },

  updated() {
    // Re-apply effects when content updates
    this.animateNewContent();
  },

  initializeLiveEffects() {
    // Add pulsing effect to live indicators
    const liveIndicators = this.el.querySelectorAll('[data-live-indicator]');
    liveIndicators.forEach(indicator => {
      indicator.style.animation = 'pulse 2s infinite';
    });

    // Add streaming data effect
    const streamingElements = this.el.querySelectorAll('[data-streaming]');
    streamingElements.forEach(el => {
      el.classList.add('animate-data-stream');
    });
  },

  setupAutoScroll() {
    // Continuous auto-scroll news feed like a live ticker
    const newsFeed = this.el.querySelector('[data-news-feed]');
    if (newsFeed) {
      this.startContinuousScroll(newsFeed);
      
      // Pause scrolling on hover
      newsFeed.addEventListener('mouseenter', () => {
        this.pauseScroll = true;
      });
      
      newsFeed.addEventListener('mouseleave', () => {
        this.pauseScroll = false;
      });
    }
  },

  startContinuousScroll(element) {
    this.pauseScroll = false;
    this.scrollSpeed = 1; // pixels per frame
    
    const scroll = () => {
      if (!this.pauseScroll && element) {
        element.scrollTop += this.scrollSpeed;
        
        // If we've scrolled to the bottom, smoothly scroll back to top
        if (element.scrollTop >= element.scrollHeight - element.clientHeight) {
          setTimeout(() => {
            element.scrollTo({
              top: 0,
              behavior: 'smooth'
            });
          }, 2000); // Wait 2 seconds at bottom
        }
      }
      
      if (element && element.isConnected) {
        requestAnimationFrame(scroll);
      }
    };
    
    // Start scrolling
    requestAnimationFrame(scroll);
  },

  addGlitchEffect() {
    // Add subtle glitch effect to live elements
    const liveElements = this.el.querySelectorAll('[data-live]');
    liveElements.forEach(el => {
      setInterval(() => {
        if (Math.random() < 0.1) { // 10% chance every interval
          el.style.textShadow = '2px 0 #ff0000, -2px 0 #00ff00';
          setTimeout(() => {
            el.style.textShadow = 'none';
          }, 100);
        }
      }, 3000);
    });
  },

  addTypingEffect() {
    // Add typing effect to new headlines
    const headlines = this.el.querySelectorAll('[data-headline]');
    headlines.forEach((headline, index) => {
      const text = headline.textContent;
      headline.textContent = '';
      
      // Stagger the typing effect
      setTimeout(() => {
        this.typeText(headline, text, 30);
      }, index * 200);
    });
  },

  typeText(element, text, speed) {
    let i = 0;
    const timer = setInterval(() => {
      if (i < text.length) {
        element.textContent += text.charAt(i);
        i++;
      } else {
        clearInterval(timer);
      }
    }, speed);
  },

  animateNewContent() {
    // Animate newly added content
    const newItems = this.el.querySelectorAll('.animate-fade-in-up:not(.animated)');
    newItems.forEach((item, index) => {
      item.classList.add('animated');
      item.style.animationDelay = `${index * 0.1}s`;
      
      // Sound disabled - no beeping
    });
  },

  // Audio notification removed - no more beeping

  startNewsTickerEffect() {
    // Add dynamic "BREAKING" and "URGENT" tags to random articles
    setInterval(() => {
      const articles = this.el.querySelectorAll('[data-headline]');
      if (articles.length > 0) {
        // Remove old breaking tags
        this.el.querySelectorAll('.breaking-tag').forEach(tag => tag.remove());
        
        // Add breaking tag to random article
        const randomArticle = articles[Math.floor(Math.random() * articles.length)];
        const breakingTag = document.createElement('span');
        breakingTag.className = 'breaking-tag text-xs bg-red-600 text-white px-2 py-1 rounded-full animate-pulse mr-2 font-bold';
        breakingTag.textContent = Math.random() > 0.7 ? '🚨 URGENT' : '📢 BREAKING';
        
        randomArticle.parentElement.insertBefore(breakingTag, randomArticle);
        
        // Flash the live indicator
        const liveIndicator = this.el.querySelector('[data-live-indicator]');
        if (liveIndicator) {
          liveIndicator.classList.add('bg-orange-500');
          setTimeout(() => {
            liveIndicator.classList.remove('bg-orange-500');
          }, 3000);
        }
      }
    }, 15000); // Add breaking tag every 15 seconds

    // Add scrolling text effect to live indicator
    const liveText = this.el.querySelector('[data-live]');
    if (liveText) {
      const messages = ['LIVE', 'REAL-TIME', 'BREAKING', 'LIVE FEED', 'NOW'];
      let messageIndex = 0;
      
      setInterval(() => {
        liveText.style.opacity = '0';
        setTimeout(() => {
          liveText.textContent = messages[messageIndex];
          liveText.style.opacity = '1';
          messageIndex = (messageIndex + 1) % messages.length;
        }, 300);
      }, 8000); // Change text every 8 seconds
    }

    // Add data streaming effect
    setInterval(() => {
      const streamingElements = this.el.querySelectorAll('[data-streaming]');
      streamingElements.forEach(el => {
        el.style.backgroundPosition = `${Math.random() * 100}% ${Math.random() * 100}%`;
      });
    }, 2000);
  }
};