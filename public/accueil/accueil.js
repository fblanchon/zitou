// Home page of zitou.fr (templates/Frontend/themes/zitou/home.html.twig): greeting that follows the visitor's clock,
// stars, confetti, the smiling "o" that follows the pointer, jumping letters, and the good thought of the day.
// Texts and pictures come from the page's data attributes; nothing moves when the visitor or the theme asks for calm.
(() => {
    const root = document.querySelector('.zitou-home');
    if (!root) {
        return;
    }
    const part = (name) => root.querySelector(`[data-zitou-home="${name}"]`);
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
        || document.documentElement.dataset.zitouAnimation === 'none';
    const language = document.documentElement.lang || 'fr';
    const now = new Date();
    const weekday = new Intl.DateTimeFormat(language, { weekday: 'long' }).format(now);

    // Greeting that follows the visitor's clock.
    const greetings = JSON.parse(root.dataset.greetings);
    const hour = now.getHours();
    let greeting = greetings.late;
    if (hour < 5) greeting = greetings.night;
    else if (hour < 12) greeting = greetings.morning;
    else if (hour < 18) greeting = greetings.afternoon;
    else if (hour < 22) greeting = greetings.evening;
    part('greeting').textContent = greeting.replace('%weekday%', weekday);

    // Stars, only visible in the dark look.
    const stars = root.querySelector('.stars');
    for (let index = 0; index < 46; index++) {
        const star = document.createElement('span');
        star.className = 'star';
        star.style.left = (Math.random() * 100).toFixed(2) + '%';
        star.style.top = (Math.random() * 78).toFixed(2) + '%';
        star.style.animationDelay = (-Math.random() * 3).toFixed(2) + 's';
        const size = Math.random() < 0.15 ? 4 : 2 + Math.random() * 1.5;
        star.style.width = star.style.height = size + 'px';
        stars.appendChild(star);
    }

    // ---------- Confetti ----------
    const canvas = part('confetti');
    const context = canvas.getContext('2d');
    const styles = getComputedStyle(root);
    const palette = ['--sun', '--tangerine', '--bubble', '--mint', '--blue'].map((name) => styles.getPropertyValue(name).trim());
    let width = 0, height = 0, particles = [], running = false;

    function resize() {
        const ratio = Math.min(window.devicePixelRatio || 1, 2);
        width = window.innerWidth;
        height = window.innerHeight;
        canvas.width = width * ratio;
        canvas.height = height * ratio;
        context.setTransform(ratio, 0, 0, ratio, 0, 0);
    }
    resize();
    window.addEventListener('resize', resize);

    function makeParticle(x, y, velocityX, velocityY) {
        return {
            x, y, velocityX, velocityY,
            size: 6 + Math.random() * 7,
            rotation: Math.random() * Math.PI,
            spin: (Math.random() - 0.5) * 0.3,
            flip: Math.random() * Math.PI,
            flipSpeed: 0.08 + Math.random() * 0.12,
            color: palette[Math.floor(Math.random() * palette.length)],
            round: Math.random() < 0.3,
        };
    }

    function burst(x, y, count = 90) {
        if (reduceMotion) return;
        for (let index = 0; index < count; index++) {
            const angle = -Math.PI / 2 + (Math.random() - 0.5) * Math.PI * 0.9;
            const speed = 6 + Math.random() * 9;
            particles.push(makeParticle(x, y, Math.cos(angle) * speed, Math.sin(angle) * speed));
        }
        start();
    }

    function rain(count = 170) {
        if (reduceMotion) return;
        for (let index = 0; index < count; index++) {
            particles.push(makeParticle(Math.random() * width, -20 - Math.random() * height * 0.6, (Math.random() - 0.5) * 3, 2 + Math.random() * 3));
        }
        start();
    }

    function start() {
        if (!running) {
            running = true;
            requestAnimationFrame(tick);
        }
    }

    function tick() {
        context.clearRect(0, 0, width, height);
        particles = particles.filter((particle) => particle.y < height + 30);
        for (const particle of particles) {
            particle.velocityY += 0.22;
            particle.velocityX *= 0.985;
            particle.velocityY *= 0.985;
            particle.x += particle.velocityX + Math.sin(particle.flip) * 0.6;
            particle.y += particle.velocityY;
            particle.rotation += particle.spin;
            particle.flip += particle.flipSpeed;
            context.save();
            context.translate(particle.x, particle.y);
            context.rotate(particle.rotation);
            context.scale(1, Math.cos(particle.flip));
            context.fillStyle = particle.color;
            if (particle.round) {
                context.beginPath();
                context.arc(0, 0, particle.size / 2, 0, Math.PI * 2);
                context.fill();
            } else {
                context.fillRect(-particle.size / 2, -particle.size / 4, particle.size, particle.size / 2);
            }
            context.restore();
        }
        if (particles.length) {
            requestAnimationFrame(tick);
        } else {
            running = false;
            context.clearRect(0, 0, width, height);
        }
    }

    // ---------- The smiling "o" ----------
    const face = part('face');
    const psst = part('psst');
    const pupils = [...face.querySelectorAll('.pupil')];
    let pointer = null, frameRequested = false;

    function lookAt() {
        frameRequested = false;
        for (const pupil of pupils) {
            const eye = pupil.parentElement.getBoundingClientRect();
            let offsetX = 0, offsetY = 0;
            if (pointer) {
                const deltaX = pointer.x - (eye.left + eye.width / 2);
                const deltaY = pointer.y - (eye.top + eye.height / 2);
                const distance = Math.hypot(deltaX, deltaY) || 1;
                const reach = Math.min(1, distance / 160);
                offsetX = deltaX / distance * eye.width * 0.24 * reach;
                offsetY = deltaY / distance * eye.height * 0.22 * reach;
            }
            pupil.style.transform = `translate(${offsetX.toFixed(1)}px, ${offsetY.toFixed(1)}px)`;
        }
    }
    function follow(event) {
        pointer = { x: event.clientX, y: event.clientY };
        if (!frameRequested) {
            frameRequested = true;
            requestAnimationFrame(lookAt);
        }
    }
    window.addEventListener('pointermove', follow, { passive: true });
    window.addEventListener('pointerdown', follow, { passive: true });

    function blink() {
        face.classList.add('blink');
        setTimeout(() => face.classList.remove('blink'), 140);
        setTimeout(blink, 2200 + Math.random() * 4200);
    }
    setTimeout(blink, 2600);

    let happyTimer;
    function beHappy(duration = 1800) {
        face.classList.add('happy');
        clearTimeout(happyTimer);
        happyTimer = setTimeout(() => face.classList.remove('happy'), duration);
    }
    function faceCenter() {
        const box = face.getBoundingClientRect();
        return { x: box.left + box.width / 2, y: box.top + box.height / 2 };
    }

    face.addEventListener('click', () => {
        psst.classList.add('gone');
        beHappy();
        const center = faceCenter();
        burst(center.x, center.y, 110);
    });

    // Letters jump when touched.
    for (const letter of root.querySelectorAll('.letter')) {
        const jump = () => {
            if (reduceMotion) return;
            letter.classList.remove('jump');
            void letter.offsetWidth;
            letter.classList.add('jump');
        };
        letter.addEventListener('pointerenter', jump);
        letter.addEventListener('pointerdown', jump);
        letter.addEventListener('animationend', () => letter.classList.remove('jump'));
    }

    part('party').addEventListener('click', () => {
        beHappy(2600);
        rain();
    });

    // A small hello once the letters have landed.
    setTimeout(() => {
        beHappy(1400);
        const center = faceCenter();
        if (center.y > 0 && center.y < height) burst(center.x, center.y, 45);
    }, 1300);

    // Gentle parallax on the floating shapes.
    const sky = root.querySelector('.sky');
    sky.addEventListener('pointermove', (event) => {
        if (reduceMotion) return;
        const box = sky.getBoundingClientRect();
        sky.style.setProperty('--px', ((event.clientX - box.left) / box.width - 0.5).toFixed(3));
        sky.style.setProperty('--py', ((event.clientY - box.top) / box.height - 0.5).toFixed(3));
    });

    // ---------- Good thought of the day, with its polaroid ----------
    const thoughts = JSON.parse(root.dataset.thoughts);
    const dayOfYear = Math.floor((now - new Date(now.getFullYear(), 0, 0)) / 86400000);
    let current = dayOfYear % thoughts.length;
    const quote = part('joy-quote');
    const polaroid = part('polaroid');
    const photo = part('joy-image');
    const caption = part('joy-caption');

    function show(thought) {
        quote.textContent = thought.text;
        photo.src = thought.image;
        photo.alt = thought.alt;
        caption.textContent = thought.caption;
    }
    show(thoughts[current]);
    part('joy-date').textContent = root.dataset.datePrefix + ' ' + new Intl.DateTimeFormat(language, { weekday: 'long', day: 'numeric', month: 'long' }).format(now);

    // Loads the next picture before swapping, so the polaroid never shows an empty frame.
    function preload(thought) {
        return new Promise((resolve) => {
            const image = new Image();
            image.onload = image.onerror = resolve;
            image.src = thought.image;
            setTimeout(resolve, 1500);
        });
    }

    part('joy-next').addEventListener('click', (event) => {
        let next;
        do {
            next = Math.floor(Math.random() * thoughts.length);
        } while (next === current);
        current = next;
        const thought = thoughts[current];
        const box = event.currentTarget.getBoundingClientRect();
        burst(box.left + box.width / 2, box.top, 30);
        quote.classList.add('out');
        polaroid.classList.add('swap');
        const delay = new Promise((resolve) => setTimeout(resolve, reduceMotion ? 0 : 230));
        Promise.all([preload(thought), delay]).then(() => {
            if (thoughts[current] !== thought) return;
            show(thought);
            quote.classList.remove('out');
            polaroid.classList.remove('swap');
        });
    });
})();
