/**
 * Professional 3D Gauge Component
 * 
 * Features:
 * - Three.js 3D rendering with WebGL
 * - Advanced particle effects and shaders
 * - Smooth animations with easing
 * - Dynamic lighting and materials
 * - Interactive hover effects
 * - Real-time data visualization
 * - Modern glass morphism UI
 */

// Load Three.js dynamically
let THREE;

async function loadThreeJS() {
  if (!THREE) {
    try {
      THREE = await import('https://cdn.skypack.dev/three@0.158.0');
    } catch (error) {
      console.warn('Failed to load Three.js from CDN, falling back to basic gauge');
      throw error;
    }
  }
  return THREE;
}

export class ProfessionalGauge {
  constructor(containerId, options = {}) {
    this.container = document.getElementById(containerId);
    this.options = {
      value: options.value || 0.5,
      minValue: options.minValue || 0,
      maxValue: options.maxValue || 1,
      category: options.category || 'sentiment',
      colors: options.colors || {},
      animated: options.animated !== false,
      particles: options.particles !== false,
      interactive: options.interactive !== false,
      ...options
    };

    this.animationId = null;
    this.particles = [];
    this.currentValue = this.options.value;
    this.targetValue = this.options.value;
    this.initialized = false;
    
    this.init();
  }

  async init() {
    try {
      await loadThreeJS();
      this.setupScene();
      this.setupLights();
      this.createGauge();
      this.createParticles();
      this.setupUI();
      this.setupEventListeners();
      this.animate();
      this.initialized = true;
    } catch (error) {
      console.error('Failed to initialize Professional Gauge:', error);
      this.createFallbackGauge();
    }
  }

  createFallbackGauge() {
    // Create a beautiful CSS-only gauge as fallback
    this.container.innerHTML = `
      <div class="fallback-gauge">
        <div class="gauge-container">
          <div class="gauge-background">
            <div class="gauge-fill" style="--gauge-value: ${this.currentValue * 100}%"></div>
            <div class="gauge-center">
              <div class="gauge-value">${this.formatValue(this.currentValue)}</div>
              <div class="gauge-label">${this.getCategoryLabel()}</div>
            </div>
          </div>
        </div>
      </div>
    `;

    // Add fallback styles
    this.addFallbackStyles();
  }

  addFallbackStyles() {
    if (document.getElementById('fallback-gauge-styles')) return;

    const style = document.createElement('style');
    style.id = 'fallback-gauge-styles';
    style.textContent = `
      .fallback-gauge {
        width: 100%;
        height: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
        background: radial-gradient(circle at center, rgba(59, 130, 246, 0.1) 0%, rgba(0, 0, 0, 0.3) 70%);
        border-radius: 12px;
        position: relative;
        overflow: hidden;
      }

      .fallback-gauge::before {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: linear-gradient(45deg, rgba(255,255,255,0.1) 0%, transparent 50%, rgba(255,255,255,0.05) 100%);
        pointer-events: none;
      }

      .gauge-container {
        width: min(100%, 260px);
        aspect-ratio: 1;
        position: relative;
        margin: 0 auto;
      }

      .gauge-background {
        width: 100%;
        height: 100%;
        border-radius: 50%;
        background: conic-gradient(
          from -135deg,
          #ef4444 0deg,
          #ff6600 60deg,
          #ffaa00 120deg,
          #ffff00 150deg,
          #88ff00 200deg,
          #10b981 270deg
        );
        padding: 8px;
        position: relative;
        animation: gaugeRotate 3s ease-in-out infinite;
      }

      @keyframes gaugeRotate {
        0%, 100% { transform: rotate(0deg); }
        50% { transform: rotate(2deg); }
      }

      .gauge-background::before {
        content: '';
        position: absolute;
        inset: 8px;
        border-radius: 50%;
        background: linear-gradient(135deg, #1f2937 0%, #111827 100%);
      }

      .gauge-fill {
        position: absolute;
        inset: 12px;
        border-radius: 50%;
        background: conic-gradient(
          from -135deg,
          transparent 0deg,
          #4facfe var(--gauge-value, 50%),
          transparent var(--gauge-value, 50%)
        );
        animation: gaugeFillPulse 2s ease-in-out infinite;
      }

      @keyframes gaugeFillPulse {
        0%, 100% { opacity: 0.8; transform: scale(1); }
        50% { opacity: 1; transform: scale(1.02); }
      }

      .gauge-center {
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        text-align: center;
        z-index: 10;
      }

      .gauge-value {
        font-size: 1.5rem;
        font-weight: 700;
        color: #ffffff;
        text-shadow: 0 0 20px rgba(68, 153, 255, 0.6);
        margin-bottom: 0.25rem;
        background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
        animation: valueGlow 1.5s ease-in-out infinite alternate;
      }

      @keyframes valueGlow {
        0% { filter: drop-shadow(0 0 5px rgba(68, 153, 255, 0.3)); }
        100% { filter: drop-shadow(0 0 15px rgba(68, 153, 255, 0.6)); }
      }

      .gauge-label {
        font-size: 0.75rem;
        color: rgba(255, 255, 255, 0.7);
        text-transform: uppercase;
        letter-spacing: 0.1em;
        font-weight: 500;
      }
    `;
    document.head.appendChild(style);
  }

  setupScene() {
    const rect = this.container.getBoundingClientRect();
    // Ensure perfect square dimensions
    const size = Math.min(rect.width, rect.height, 280);
    
    // Scene
    this.scene = new THREE.Scene();
    this.scene.fog = new THREE.Fog(0x0a0a0a, 10, 50);
    
    // Camera
    this.camera = new THREE.PerspectiveCamera(
      45, 
      1, // Perfect 1:1 aspect ratio for circular gauge
      0.1, 
      1000
    );
    this.camera.position.set(0, 0, 12);
    
    // Renderer with advanced settings
    this.renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: true,
      powerPreference: "high-performance"
    });
    
    // Set exact square dimensions
    this.renderer.setSize(size, size);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.2;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    
    // Style the canvas for perfect centering and proportions
    this.renderer.domElement.style.display = 'block';
    this.renderer.domElement.style.margin = '0 auto';
    this.renderer.domElement.style.width = `${size}px`;
    this.renderer.domElement.style.height = `${size}px`;
    this.renderer.domElement.style.borderRadius = '8px';
    
    this.container.appendChild(this.renderer.domElement);
  }

  setupLights() {
    // Ambient light
    const ambientLight = new THREE.AmbientLight(0x2a2a4a, 0.3);
    this.scene.add(ambientLight);

    // Main directional light
    const directionalLight = new THREE.DirectionalLight(0xffffff, 1.5);
    directionalLight.position.set(10, 10, 10);
    directionalLight.castShadow = true;
    directionalLight.shadow.mapSize.width = 2048;
    directionalLight.shadow.mapSize.height = 2048;
    this.scene.add(directionalLight);

    // Rim light
    const rimLight = new THREE.DirectionalLight(0x4a90ff, 0.5);
    rimLight.position.set(-10, 5, -10);
    this.scene.add(rimLight);

    // Point lights for dynamic color effects
    this.colorLight = new THREE.PointLight(0x00ff88, 2, 20);
    this.colorLight.position.set(0, 0, 8);
    this.scene.add(this.colorLight);
  }

  createGauge() {
    this.gaugeGroup = new THREE.Group();
    
    // Outer ring (bezel)
    const outerGeometry = new THREE.TorusGeometry(5, 0.3, 16, 64);
    const outerMaterial = new THREE.MeshPhysicalMaterial({
      color: 0x1a1a2e,
      metalness: 0.9,
      roughness: 0.1,
      clearcoat: 1.0,
      clearcoatRoughness: 0.05,
    });
    this.outerRing = new THREE.Mesh(outerGeometry, outerMaterial);
    this.gaugeGroup.add(this.outerRing);

    // Background disc
    const discGeometry = new THREE.CylinderGeometry(4.5, 4.5, 0.1, 64);
    const discMaterial = new THREE.MeshPhysicalMaterial({
      color: 0x0f0f1a,
      metalness: 0.1,
      roughness: 0.9,
      transmission: 0.1,
      thickness: 0.5,
    });
    this.backgroundDisc = new THREE.Mesh(discGeometry, discMaterial);
    this.backgroundDisc.rotation.x = Math.PI / 2;
    this.gaugeGroup.add(this.backgroundDisc);

    // Create arc segments
    this.createArcSegments();
    
    // Needle
    this.createNeedle();
    
    // Center hub
    const hubGeometry = new THREE.CylinderGeometry(0.5, 0.6, 0.4, 16);
    const hubMaterial = new THREE.MeshPhysicalMaterial({
      color: 0x2a2a4a,
      metalness: 0.8,
      roughness: 0.2,
      clearcoat: 1.0,
    });
    this.hub = new THREE.Mesh(hubGeometry, hubMaterial);
    this.hub.rotation.x = Math.PI / 2;
    this.gaugeGroup.add(this.hub);

    this.scene.add(this.gaugeGroup);
  }

  createArcSegments() {
    const segments = 60;
    const startAngle = Math.PI * 0.75; // Start from bottom left
    const endAngle = Math.PI * 0.25;   // End at bottom right
    const totalAngle = (2 * Math.PI) - (startAngle - endAngle);
    
    this.arcSegments = [];
    
    for (let i = 0; i < segments; i++) {
      const angle = startAngle + (totalAngle * i / segments);
      const nextAngle = startAngle + (totalAngle * (i + 1) / segments);
      
      // Create individual segment
      const segmentGeometry = new THREE.RingGeometry(3.5, 4.3, 0, 1);
      segmentGeometry.rotateZ(angle);
      
      // Color based on position and category
      const normalizedPos = i / segments;
      const color = this.getSegmentColor(normalizedPos);
      
      const segmentMaterial = new THREE.MeshPhysicalMaterial({
        color: color,
        metalness: 0.3,
        roughness: 0.4,
        emissive: new THREE.Color(color).multiplyScalar(0.1),
        transparent: true,
        opacity: 0.7,
      });
      
      const segment = new THREE.Mesh(segmentGeometry, segmentMaterial);
      segment.rotation.x = Math.PI / 2;
      segment.userData = { normalizedPos, originalColor: color };
      
      this.arcSegments.push(segment);
      this.gaugeGroup.add(segment);
    }
  }

  getSegmentColor(normalizedPos) {
    if (this.options.category === 'sentiment') {
      // Sentiment goes from Red (0% - negative) to Yellow (50% - neutral) to Green (100% - positive)
      if (normalizedPos < 0.5) {
        // Red to Yellow transition (0% to 50%)
        const factor = normalizedPos * 2; // 0 to 1
        const red = 255;
        const green = Math.floor(165 * factor); // 0 to 165 (for orange/yellow)
        return (red << 16) | (green << 8) | 0;
      } else {
        // Yellow to Green transition (50% to 100%)
        const factor = (normalizedPos - 0.5) * 2; // 0 to 1
        const red = Math.floor(255 * (1 - factor)); // 255 to 0
        const green = 255;
        return (red << 16) | (green << 8) | 0;
      }
    }
    
    // Default gradient for other categories
    const red = Math.max(0, Math.min(255, 255 * (1 - normalizedPos)));
    const green = Math.max(0, Math.min(255, 255 * normalizedPos));
    return (red << 16) | (green << 8) | 0x44;
  }

  createNeedle() {
    const needleGroup = new THREE.Group();
    
    // Needle body - more prominent
    const needleGeometry = new THREE.ConeGeometry(0.08, 3.8, 8);
    const needleMaterial = new THREE.MeshPhysicalMaterial({
      color: 0xffffff,
      metalness: 0.95,
      roughness: 0.05,
      emissive: 0xffffff,
      emissiveIntensity: 0.4,
    });
    
    this.needle = new THREE.Mesh(needleGeometry, needleMaterial);
    this.needle.position.y = 1.9;
    this.needle.rotation.x = Math.PI / 2;
    
    needleGroup.add(this.needle);
    
    // Needle glow effect - more visible
    const glowGeometry = new THREE.ConeGeometry(0.15, 3.8, 8);
    const glowMaterial = new THREE.MeshBasicMaterial({
      color: 0xffffff,
      transparent: true,
      opacity: 0.6,
    });
    
    const needleGlow = new THREE.Mesh(glowGeometry, glowMaterial);
    needleGlow.position.copy(this.needle.position);
    needleGlow.rotation.copy(this.needle.rotation);
    needleGlow.scale.setScalar(1.3);
    
    needleGroup.add(needleGlow);
    
    // Add needle tip highlight
    const tipGeometry = new THREE.SphereGeometry(0.12, 8, 8);
    const tipMaterial = new THREE.MeshPhysicalMaterial({
      color: 0xffffff,
      metalness: 1.0,
      roughness: 0.0,
      emissive: 0xffffff,
      emissiveIntensity: 0.5,
    });
    
    const needleTip = new THREE.Mesh(tipGeometry, tipMaterial);
    needleTip.position.y = 3.7;
    needleGroup.add(needleTip);
    
    this.needleGroup = needleGroup;
    this.gaugeGroup.add(needleGroup);
    
    // Set initial needle position
    this.updateNeedle(this.currentValue);
  }

  createParticles() {
    if (!this.options.particles) return;
    
    const particleCount = 100;
    const geometry = new THREE.BufferGeometry();
    const positions = new Float32Array(particleCount * 3);
    const velocities = new Float32Array(particleCount * 3);
    const colors = new Float32Array(particleCount * 3);
    
    for (let i = 0; i < particleCount; i++) {
      const i3 = i * 3;
      
      // Random position around gauge
      const angle = Math.random() * Math.PI * 2;
      const radius = 6 + Math.random() * 4;
      
      positions[i3] = Math.cos(angle) * radius;
      positions[i3 + 1] = (Math.random() - 0.5) * 2;
      positions[i3 + 2] = Math.sin(angle) * radius;
      
      // Random velocities
      velocities[i3] = (Math.random() - 0.5) * 0.02;
      velocities[i3 + 1] = (Math.random() - 0.5) * 0.02;
      velocities[i3 + 2] = (Math.random() - 0.5) * 0.02;
      
      // Colors based on category
      const color = new THREE.Color(this.getSegmentColor(Math.random()));
      colors[i3] = color.r;
      colors[i3 + 1] = color.g;
      colors[i3 + 2] = color.b;
    }
    
    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geometry.setAttribute('velocity', new THREE.BufferAttribute(velocities, 3));
    geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    
    const particleMaterial = new THREE.PointsMaterial({
      size: 0.05,
      transparent: true,
      opacity: 0.8,
      vertexColors: true,
      blending: THREE.AdditiveBlending,
    });
    
    this.particleSystem = new THREE.Points(geometry, particleMaterial);
    this.scene.add(this.particleSystem);
  }

  setupUI() {
    // Create modern UI overlay
    const uiContainer = document.createElement('div');
    uiContainer.className = 'gauge-ui-overlay';
    uiContainer.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      pointer-events: none;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      font-family: 'Inter', system-ui, sans-serif;
    `;

    // Main value display
    this.valueDisplay = document.createElement('div');
    this.valueDisplay.className = 'gauge-value';
    this.valueDisplay.style.cssText = `
      font-size: 2.5rem;
      font-weight: 700;
      color: #ffffff;
      text-shadow: 0 0 20px rgba(68, 153, 255, 0.6);
      margin-bottom: 0.5rem;
      background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
      filter: drop-shadow(0 0 10px rgba(68, 153, 255, 0.3));
    `;

    // Category label
    const categoryLabel = document.createElement('div');
    categoryLabel.textContent = this.getCategoryLabel();
    categoryLabel.style.cssText = `
      font-size: 0.875rem;
      color: rgba(255, 255, 255, 0.7);
      text-transform: uppercase;
      letter-spacing: 0.1em;
      font-weight: 500;
    `;

    // Animated background glow
    const glowOverlay = document.createElement('div');
    glowOverlay.style.cssText = `
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: 200px;
      height: 200px;
      border-radius: 50%;
      background: radial-gradient(circle, rgba(68, 153, 255, 0.1) 0%, transparent 70%);
      animation: pulse 2s ease-in-out infinite alternate;
    `;

    uiContainer.appendChild(glowOverlay);
    uiContainer.appendChild(this.valueDisplay);
    uiContainer.appendChild(categoryLabel);
    
    this.container.appendChild(uiContainer);

    // Add CSS animation
    const style = document.createElement('style');
    style.textContent = `
      @keyframes pulse {
        0% { transform: translate(-50%, -50%) scale(0.95); opacity: 0.7; }
        100% { transform: translate(-50%, -50%) scale(1.05); opacity: 0.3; }
      }
      
      .gauge-ui-overlay {
        transition: opacity 0.3s ease;
      }
      
      .gauge-value {
        transition: all 0.5s cubic-bezier(0.4, 0, 0.2, 1);
      }
    `;
    document.head.appendChild(style);

    this.updateValueDisplay();
  }

  setupEventListeners() {
    if (!this.options.interactive) return;

    this.container.addEventListener('mouseenter', () => {
      this.gaugeGroup.rotation.x = 0.1;
      this.colorLight.intensity = 3;
    });

    this.container.addEventListener('mouseleave', () => {
      this.gaugeGroup.rotation.x = 0;
      this.colorLight.intensity = 2;
    });

    // Handle resize
    window.addEventListener('resize', () => {
      const rect = this.container.getBoundingClientRect();
      const size = Math.min(rect.width, rect.height);
      this.camera.aspect = 1; // Keep 1:1 aspect ratio
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(size, size);
    });
  }

  updateValue(newValue, animated = true) {
    this.targetValue = Math.max(this.options.minValue, 
                               Math.min(this.options.maxValue, newValue));
    
    if (!animated) {
      this.currentValue = this.targetValue;
      if (this.initialized) {
        this.updateNeedle(this.currentValue);
        this.updateValueDisplay();
        this.updateArcHighlight();
      } else {
        this.updateFallbackGauge();
      }
    }
  }

  updateFallbackGauge() {
    const fillElement = this.container.querySelector('.gauge-fill');
    const valueElement = this.container.querySelector('.gauge-value');
    
    if (fillElement) {
      fillElement.style.setProperty('--gauge-value', `${this.currentValue * 100}%`);
    }
    
    if (valueElement) {
      valueElement.textContent = this.formatValue(this.currentValue);
    }
  }

  updateNeedle(value) {
    const normalizedValue = (value - this.options.minValue) / 
                           (this.options.maxValue - this.options.minValue);
    
    // For sentiment: gauge spans from -135° (negative/red) to +135° (positive/green)
    // -135° = bottom-left, 0° = top, +135° = bottom-right
    const startAngle = -Math.PI * 0.75; // -135° (negative sentiment)
    const endAngle = Math.PI * 0.75;    // +135° (positive sentiment)
    const angle = startAngle + (endAngle - startAngle) * normalizedValue;
    
    if (this.needleGroup) {
      this.needleGroup.rotation.z = angle;
    }
    
    // Update needle color based on sentiment value
    if (this.options.category === 'sentiment' && this.needle) {
      const needleColor = this.getNeedleColor(normalizedValue);
      this.needle.material.emissive.setHex(needleColor);
    }
  }

  getNeedleColor(normalizedValue) {
    if (normalizedValue < 0.5) {
      // Red to Yellow transition (0% to 50%)
      const factor = normalizedValue * 2;
      return new THREE.Color().lerpColors(
        new THREE.Color(0xff0000), // Red
        new THREE.Color(0xffaa00), // Orange-Yellow
        factor
      ).getHex();
    } else {
      // Yellow to Green transition (50% to 100%)  
      const factor = (normalizedValue - 0.5) * 2;
      return new THREE.Color().lerpColors(
        new THREE.Color(0xffaa00), // Orange-Yellow
        new THREE.Color(0x00ff00), // Green
        factor
      ).getHex();
    }
  }

  updateValueDisplay() {
    if (this.valueDisplay) {
      const displayValue = this.formatValue(this.currentValue);
      this.valueDisplay.textContent = displayValue;
      
      // Update color based on value
      const normalizedValue = (this.currentValue - this.options.minValue) / 
                             (this.options.maxValue - this.options.minValue);
      const color = this.getDisplayColor(normalizedValue);
      this.valueDisplay.style.background = `linear-gradient(135deg, ${color} 0%, ${color}aa 100%)`;
    }
  }

  updateArcHighlight() {
    const normalizedValue = (this.currentValue - this.options.minValue) / 
                           (this.options.maxValue - this.options.minValue);
    
    this.arcSegments.forEach((segment, index) => {
      const segmentPos = index / this.arcSegments.length;
      const isActive = segmentPos <= normalizedValue;
      
      segment.material.opacity = isActive ? 1.0 : 0.3;
      segment.material.emissiveIntensity = isActive ? 0.3 : 0.05;
    });
  }

  animate() {
    this.animationId = requestAnimationFrame(() => this.animate());
    
    const time = Date.now() * 0.001;
    
    // Smooth value interpolation
    if (Math.abs(this.currentValue - this.targetValue) > 0.001) {
      this.currentValue += (this.targetValue - this.currentValue) * 0.05;
      this.updateNeedle(this.currentValue);
      this.updateValueDisplay();
      this.updateArcHighlight();
    }
    
    // Animate particles
    if (this.particleSystem) {
      const positions = this.particleSystem.geometry.attributes.position.array;
      const velocities = this.particleSystem.geometry.attributes.velocity.array;
      
      for (let i = 0; i < positions.length; i += 3) {
        positions[i] += velocities[i];
        positions[i + 1] += velocities[i + 1];
        positions[i + 2] += velocities[i + 2];
        
        // Reset particles that move too far
        const distance = Math.sqrt(
          positions[i] ** 2 + 
          positions[i + 1] ** 2 + 
          positions[i + 2] ** 2
        );
        
        if (distance > 15) {
          const angle = Math.random() * Math.PI * 2;
          const radius = 6 + Math.random() * 2;
          positions[i] = Math.cos(angle) * radius;
          positions[i + 1] = (Math.random() - 0.5) * 2;
          positions[i + 2] = Math.sin(angle) * radius;
        }
      }
      
      this.particleSystem.geometry.attributes.position.needsUpdate = true;
    }
    
    // Rotate gauge group slightly
    if (this.gaugeGroup) {
      this.gaugeGroup.rotation.y = Math.sin(time * 0.1) * 0.05;
    }
    
    // Animate color light
    this.colorLight.color.setHSL((time * 0.1) % 1, 0.7, 0.5);
    this.colorLight.position.x = Math.sin(time * 0.2) * 5;
    this.colorLight.position.z = Math.cos(time * 0.2) * 5;
    
    this.renderer.render(this.scene, this.camera);
  }

  formatValue(value) {
    if (this.options.category === 'sentiment') {
      const percent = Math.round(value * 100);
      if (value > 0.6) return `${percent}% Positive`;
      if (value < 0.4) return `${percent}% Negative`;
      return `${percent}% Neutral`;
    }
    
    return `${value.toFixed(1)}`;
  }

  getDisplayColor(normalizedValue) {
    if (this.options.category === 'sentiment') {
      if (normalizedValue < 0.33) return '#ef4444'; // Red - negative
      if (normalizedValue < 0.66) return '#ffaa00'; // Orange/Yellow - neutral
      return '#10b981'; // Green - positive
    }
    
    return '#4facfe';
  }

  getCategoryLabel() {
    const labels = {
      sentiment: 'Global Sentiment',
      financial: 'Financial Pulse',
      natural_events: 'Natural Events',
      social_trends: 'Social Trends'
    };
    
    return labels[this.options.category] || 'Metric';
  }

  destroy() {
    if (this.animationId) {
      cancelAnimationFrame(this.animationId);
    }
    
    if (this.renderer) {
      this.renderer.dispose();
    }
    
    if (this.container && this.renderer.domElement) {
      this.container.removeChild(this.renderer.domElement);
    }
  }
}