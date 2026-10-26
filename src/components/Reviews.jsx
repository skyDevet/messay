import { useState } from 'react';
import { useStore } from '../data/store.js';

// Before/after slider images, with SVG placeholders used when the real image is missing or fails to load
const BA_BEFORE_SRC = 'co/before-project.png';
const BA_AFTER_SRC = 'co/after-project.png';
const BA_BEFORE_PLACEHOLDER = 'co/before-placeholder.png';
const BA_AFTER_PLACEHOLDER = 'co/after-placeholder.png';
const baOnError = (placeholder) => (e) => {
  const img = e.currentTarget;
  if (img.getAttribute('src') !== placeholder) img.setAttribute('src', placeholder);
};

export function Reviews() {
  const [data, lang] = useStore();
  const [sliderPos, setSliderPos] = useState(50); // 50% default position

  return (
    <section class="section alt">
      <div class="container">
        
        {/* --- REVIEWS SECTION (Unchanged) --- */}
        <div class="section-header">
         <h2>{lang === 'am' ? 'የደንበኞች አስተያየት' : 'What Clients Say'}</h2>
         </div>
                <div class="reviews-grid">
          {data.reviews.map(r => (
            <div class="review-card" key={r.name}>
              <div class="review-stars">{'★'.repeat(r.stars)}</div>
              <p>"{r.text}"</p>
              <div class="review-author">{r.name}</div>
              <div class="review-loc">{r.loc}</div>
            </div>
          ))}
        </div>


        {/* --- BEFORE & AFTER SLIDER SECTION --- */}
        <div class="section-header" style={{ marginTop: '4rem' }}>
          
          <h2>{lang === 'am' ? 'የፕሮጀክት ለውጥ' : 'Project Transformations'}</h2>
          <p style={{ color: 'var(--text-muted, #666)', marginTop: '0.5rem' }}>
            {lang === 'am' ? 'በፊት እና በኋላ ያለውን ልዩነት ለማየት መስመሩን ይጎትቱ' : 'Drag the slider to see the before and after'}
          </p>
        </div>

        {/* Replace these with your actual image paths */}
        <div class="before-after-wrapper">
          {/* Before Image (Background) */}
          <img 
            src={BA_BEFORE_SRC || BA_BEFORE_PLACEHOLDER}
            onError={baOnError(BA_BEFORE_PLACEHOLDER)} 
            alt="Before Construction" 
            class="ba-image ba-before" 
          />
          
          {/* After Image (Foreground, clipped by slider) */}
          <div 
            class="ba-after-clip" 
            style={{ width: `${sliderPos}%` }}
          >
            <img 
              src={BA_AFTER_SRC || BA_AFTER_PLACEHOLDER}
              onError={baOnError(BA_AFTER_PLACEHOLDER)} 
              alt="After Construction" 
              class="ba-image ba-after" 
            />
          </div>

          {/* Draggable Slider Line & Handle */}
          <div class="ba-slider-line" style={{ left: `${sliderPos}%` }}>
            <div class="ba-slider-handle">
              <span>↔</span>
            </div>
          </div>

          {/* Invisible Range Input to control the slider */}
          <input 
            type="range" 
            min="0" 
            max="100" 
            value={sliderPos} 
            onChange={(e) => setSliderPos(e.target.value)} 
            class="ba-range-input"
            aria-label="Before and after slider"
          />
          
          {/* Labels */}
          <span class="ba-label ba-label-before">Before</span>
          <span class="ba-label ba-label-after">After</span>
        </div>

      </div>
    </section>
  );
}
