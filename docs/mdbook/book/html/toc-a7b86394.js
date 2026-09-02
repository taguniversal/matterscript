// Populate the sidebar
//
// This is a script, and not included directly in the page, to control the total size of the book.
// The TOC contains an entry for each page, so if each page includes a copy of the TOC,
// the total size of the page becomes O(n**2).
class MDBookSidebarScrollbox extends HTMLElement {
    constructor() {
        super();
    }
    connectedCallback() {
        this.innerHTML = '<ol class="chapter"><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="foreword.html">Foreword</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="introduction.html">Introduction: The Missing Dimension in Programming</a></span></li><li class="chapter-item expanded "><li class="part-title">Part I: Rethinking Computation</li></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-01-rethinking-computation/index.html"><strong aria-hidden="true">1.</strong> Introduction</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-01-rethinking-computation/01-why-software-forgot-geometry.html"><strong aria-hidden="true">2.</strong> Why Software Forgot Geometry</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-01-rethinking-computation/02-time-is-not-a-clock.html"><strong aria-hidden="true">3.</strong> Time is Not a Clock</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-01-rethinking-computation/03-the-cost-of-abstraction.html"><strong aria-hidden="true">4.</strong> The Cost of Abstraction</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-01-rethinking-computation/04-hardware-already-knows-the-answer.html"><strong aria-hidden="true">5.</strong> Hardware Already Knows the Answer</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-01-rethinking-computation/05-introducing-space-time-programming.html"><strong aria-hidden="true">6.</strong> Introducing Space-Time Programming</a></span></li><li class="chapter-item expanded "><li class="part-title">Part II: The Computational Universe</li></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-02-computational-universe/index.html"><strong aria-hidden="true">7.</strong> Introduction</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-02-computational-universe/01-computation-as-propagation.html"><strong aria-hidden="true">8.</strong> Computation as Propagation</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-02-computational-universe/02-geometry-as-information.html"><strong aria-hidden="true">9.</strong> Geometry as Information</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-02-computational-universe/03-tokens-instead-of-variables.html"><strong aria-hidden="true">10.</strong> Tokens Instead of Variables</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-02-computational-universe/04-events-instead-of-execution.html"><strong aria-hidden="true">11.</strong> Events Instead of Execution</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-02-computational-universe/05-locality-as-a-programming-primitive.html"><strong aria-hidden="true">12.</strong> Locality as a Programming Primitive</a></span></li><li class="chapter-item expanded "><li class="part-title">Part III: Asynchronous Thinking</li></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-03-asynchronous-thinking/index.html"><strong aria-hidden="true">13.</strong> Introduction</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-03-asynchronous-thinking/01-why-clocks-are-artificial.html"><strong aria-hidden="true">14.</strong> Why Clocks Are Artificial</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-03-asynchronous-thinking/02-when-absence-becomes-information.html"><strong aria-hidden="true">15.</strong> When Absence Becomes Information</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-03-asynchronous-thinking/03-completeness-and-tokens.html"><strong aria-hidden="true">16.</strong> Completeness and Tokens</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-03-asynchronous-thinking/04-invocation-programming-language.html"><strong aria-hidden="true">17.</strong> Invocation Programming Language</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-03-asynchronous-thinking/05-sequential-programs-as-special-cases.html"><strong aria-hidden="true">18.</strong> Sequential Programs as Special Cases</a></span></li><li class="chapter-item expanded "><li class="part-title">Part IV: Learning MatterScript</li></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-04-learning-matterscript/index.html"><strong aria-hidden="true">19.</strong> Introduction</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-04-learning-matterscript/01-language-overview.html"><strong aria-hidden="true">20.</strong> Language Overview</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-04-learning-matterscript/02-files-and-projects.html"><strong aria-hidden="true">21.</strong> Files and Projects</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-04-learning-matterscript/03-definitions.html"><strong aria-hidden="true">22.</strong> Definitions</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-04-learning-matterscript/04-places.html"><strong aria-hidden="true">23.</strong> Places</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-04-learning-matterscript/05-tokens.html"><strong aria-hidden="true">24.</strong> Tokens</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-04-learning-matterscript/06-fields-of-resolution.html"><strong aria-hidden="true">25.</strong> Fields of Resolution</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-04-learning-matterscript/07-transform-rules.html"><strong aria-hidden="true">26.</strong> Transform Rules</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-04-learning-matterscript/08-invocation.html"><strong aria-hidden="true">27.</strong> Invocation</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-04-learning-matterscript/09-name-composition.html"><strong aria-hidden="true">28.</strong> Name Composition</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-04-learning-matterscript/10-mutexes-arbitration-bundling.html"><strong aria-hidden="true">29.</strong> Mutexes, Arbitration and Bundling</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-04-learning-matterscript/10-generate-blocks.html"><strong aria-hidden="true">30.</strong> Generate Blocks</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-04-learning-matterscript/11-integer-quantization.html"><strong aria-hidden="true">31.</strong> Integer Quantization</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-04-learning-matterscript/12-runtime-boundary.html"><strong aria-hidden="true">32.</strong> The Runtime Boundary</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-04-learning-matterscript/13-standard-library.html"><strong aria-hidden="true">33.</strong> Standard Library</a></span></li><li class="chapter-item expanded "><li class="part-title">Part V: Geometry Becomes Code</li></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-05-geometry-becomes-code/index.html"><strong aria-hidden="true">34.</strong> Introduction</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-05-geometry-becomes-code/01-meshes.html"><strong aria-hidden="true">35.</strong> Meshes</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-05-geometry-becomes-code/02-vertices.html"><strong aria-hidden="true">36.</strong> Vertices</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-05-geometry-becomes-code/03-cell-placement.html"><strong aria-hidden="true">37.</strong> Cell Placement</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-05-geometry-becomes-code/04-conformal-projection.html"><strong aria-hidden="true">38.</strong> Conformal Projection</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-05-geometry-becomes-code/05-delay-synthesis.html"><strong aria-hidden="true">39.</strong> Delay Synthesis</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-05-geometry-becomes-code/06-sensor-placement.html"><strong aria-hidden="true">40.</strong> Sensor Placement</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-05-geometry-becomes-code/07-hardware-fidelity.html"><strong aria-hidden="true">41.</strong> Hardware Fidelity</a></span></li><li class="chapter-item expanded "><li class="part-title">Part VI: Building Physical Systems</li></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-06-building-physical-systems/index.html"><strong aria-hidden="true">42.</strong> Introduction</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-06-building-physical-systems/01-cellular-automata.html"><strong aria-hidden="true">43.</strong> Cellular Automata</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-06-building-physical-systems/02-heat-flow.html"><strong aria-hidden="true">44.</strong> Heat Flow</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-06-building-physical-systems/03-fluid-flow.html"><strong aria-hidden="true">45.</strong> Fluid Flow</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-06-building-physical-systems/04-elastic-materials.html"><strong aria-hidden="true">46.</strong> Elastic Materials</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-06-building-physical-systems/05-electromagnetic-fields.html"><strong aria-hidden="true">47.</strong> Electromagnetic Fields</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-06-building-physical-systems/06-biological-systems.html"><strong aria-hidden="true">48.</strong> Biological Systems</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-06-building-physical-systems/07-multi-physics-coupling.html"><strong aria-hidden="true">49.</strong> Multi-Physics Coupling</a></span></li><li class="chapter-item expanded "><li class="part-title">Part VII: Programming Space-Time</li></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-07-programming-space-time/index.html"><strong aria-hidden="true">50.</strong> Introduction</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-07-programming-space-time/01-propagation-instead-of-execution.html"><strong aria-hidden="true">51.</strong> Propagation Instead of Execution</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-07-programming-space-time/02-space-time-coordinates.html"><strong aria-hidden="true">52.</strong> Space-Time Coordinates</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-07-programming-space-time/03-local-causality.html"><strong aria-hidden="true">53.</strong> Local Causality</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-07-programming-space-time/04-global-emergence.html"><strong aria-hidden="true">54.</strong> Global Emergence</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-07-programming-space-time/05-deterministic-physical-computing.html"><strong aria-hidden="true">55.</strong> Deterministic Physical Computing</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-07-programming-space-time/06-software-meets-semiconductor-physics.html"><strong aria-hidden="true">56.</strong> Software Meets Semiconductor Physics</a></span></li><li class="chapter-item expanded "><li class="part-title">Part VIII: Compilers</li></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-08-compilers/index.html"><strong aria-hidden="true">57.</strong> Introduction</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-08-compilers/01-parsing.html"><strong aria-hidden="true">58.</strong> Parsing</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-08-compilers/02-abstract-syntax-trees.html"><strong aria-hidden="true">59.</strong> Abstract Syntax Trees</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-08-compilers/03-neighborhood-rules.html"><strong aria-hidden="true">60.</strong> Neighborhood Rules</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-08-compilers/04-placement-algorithms.html"><strong aria-hidden="true">61.</strong> Placement Algorithms</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-08-compilers/05-delay-insertion.html"><strong aria-hidden="true">62.</strong> Delay Insertion</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-08-compilers/06-vhdl-generation.html"><strong aria-hidden="true">63.</strong> VHDL Generation</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-08-compilers/07-fpga-synthesis.html"><strong aria-hidden="true">64.</strong> FPGA Synthesis</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-08-compilers/08-c-posix-code-generation.html"><strong aria-hidden="true">65.</strong> C &amp; POSIX Code Generation</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-08-compilers/09-nuttx-rtos-embedded.html"><strong aria-hidden="true">66.</strong> POSIX Runtimes</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-08-compilers/10-verification.html"><strong aria-hidden="true">67.</strong> Verification</a></span></li><li class="chapter-item expanded "><li class="part-title">Part IX: World Modeling</li></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-09-world-modeling/index.html"><strong aria-hidden="true">68.</strong> Introduction</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-09-world-modeling/01-engineering-knowledge-as-software.html"><strong aria-hidden="true">69.</strong> Engineering Knowledge as Software</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-09-world-modeling/02-building-a-radiator.html"><strong aria-hidden="true">70.</strong> Building a Radiator</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-09-world-modeling/03-from-radiator-to-automobile.html"><strong aria-hidden="true">71.</strong> From Radiator to Automobile</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-09-world-modeling/04-from-automobile-to-city.html"><strong aria-hidden="true">72.</strong> From Automobile to City</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-09-world-modeling/05-human-ai-collaboration.html"><strong aria-hidden="true">73.</strong> Human-AI Collaboration</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-09-world-modeling/06-executable-world-models.html"><strong aria-hidden="true">74.</strong> Executable World Models</a></span></li><li class="chapter-item expanded "><li class="part-title">Part X: Distributed Space-Time Systems</li></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-10-distributed-space-time-systems/index.html"><strong aria-hidden="true">75.</strong> Introduction</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-10-distributed-space-time-systems/01-distributed-tokens.html"><strong aria-hidden="true">76.</strong> Distributed Tokens</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-10-distributed-space-time-systems/02-temporal-address-spaces.html"><strong aria-hidden="true">77.</strong> Temporal Address Spaces</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-10-distributed-space-time-systems/03-deterministic-synchronization.html"><strong aria-hidden="true">78.</strong> Deterministic Synchronization</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-10-distributed-space-time-systems/04-edge-computing.html"><strong aria-hidden="true">79.</strong> Edge Computing</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-10-distributed-space-time-systems/05-robotics.html"><strong aria-hidden="true">80.</strong> Robotics</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-10-distributed-space-time-systems/06-digital-twins.html"><strong aria-hidden="true">81.</strong> Digital Twins</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-10-distributed-space-time-systems/07-planetary-scale-simulation.html"><strong aria-hidden="true">82.</strong> Planetary Scale Simulation</a></span></li><li class="chapter-item expanded "><li class="part-title">Part XI: Complete Projects</li></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-11-complete-projects/index.html"><strong aria-hidden="true">83.</strong> Introduction</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-11-complete-projects/01-conways-game-of-life.html"><strong aria-hidden="true">84.</strong> Conway&#39;s Game of Life</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-11-complete-projects/02-heat-plate.html"><strong aria-hidden="true">85.</strong> Heat Plate</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-11-complete-projects/03-river-simulation.html"><strong aria-hidden="true">86.</strong> River Simulation</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-11-complete-projects/04-wind-tunnel.html"><strong aria-hidden="true">87.</strong> Wind Tunnel</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-11-complete-projects/05-autonomous-vehicle-sensor-model.html"><strong aria-hidden="true">88.</strong> Autonomous Vehicle Sensor Model</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-11-complete-projects/06-cpu-cache-simulation.html"><strong aria-hidden="true">89.</strong> CPU Cache Simulation</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-11-complete-projects/07-smart-factory.html"><strong aria-hidden="true">90.</strong> Smart Factory</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-11-complete-projects/08-drone-swarm.html"><strong aria-hidden="true">91.</strong> Drone Swarm</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-11-complete-projects/09-automotive-radiator.html"><strong aria-hidden="true">92.</strong> Automotive Radiator</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="part-11-complete-projects/10-digital-earth.html"><strong aria-hidden="true">93.</strong> Digital Earth</a></span></li><li class="chapter-item expanded "><li class="spacer"></li></li><li class="chapter-item expanded "><li class="part-title">Appendices</li></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="appendices/appendix-a-language-reference.html"><strong aria-hidden="true">94.</strong> Appendix A: Language Reference</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="appendices/appendix-b-grammar-specification.html"><strong aria-hidden="true">95.</strong> Appendix B: Grammar Specification</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="appendices/appendix-c-compiler-internals.html"><strong aria-hidden="true">96.</strong> Appendix C: Compiler Internals</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="appendices/appendix-d-standard-library-reference.html"><strong aria-hidden="true">97.</strong> Appendix D: Standard Library Reference</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="appendices/appendix-e-invocation-language-reference.html"><strong aria-hidden="true">98.</strong> Appendix E: Invocation Language Reference</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="appendices/appendix-f-mathematics-of-geometry-aware-placement.html"><strong aria-hidden="true">99.</strong> Appendix F: Mathematics of Geometry-Aware Placement</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="appendices/appendix-g-building-the-compiler.html"><strong aria-hidden="true">100.</strong> Appendix G: Building the Compiler</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="appendices/appendix-h-future-directions.html"><strong aria-hidden="true">101.</strong> Appendix H: Future Directions</a></span></li></ol>';
        // Set the current, active page, and reveal it if it's hidden
        let current_page = document.location.href.toString().split('#')[0].split('?')[0];
        if (current_page.endsWith('/')) {
            current_page += 'index.html';
        }
        const links = Array.prototype.slice.call(this.querySelectorAll('a'));
        const l = links.length;
        for (let i = 0; i < l; ++i) {
            const link = links[i];
            const href = link.getAttribute('href');
            if (href && !href.startsWith('#') && !/^(?:[a-z+]+:)?\/\//.test(href)) {
                link.href = path_to_root + href;
            }
            // The 'index' page is supposed to alias the first chapter in the book.
            // Check both with and without the '.html' suffix to be robust against pretty URLs
            if (link.href.replace(/\.html$/, '') === current_page.replace(/\.html$/, '')
                || i === 0
                && path_to_root === ''
                && current_page.endsWith('/index.html')) {
                link.classList.add('active');
                let parent = link.parentElement;
                while (parent) {
                    if (parent.tagName === 'LI' && parent.classList.contains('chapter-item')) {
                        parent.classList.add('expanded');
                    }
                    parent = parent.parentElement;
                }
            }
        }
        // Track and set sidebar scroll position
        this.addEventListener('click', e => {
            if (e.target.tagName === 'A') {
                const clientRect = e.target.getBoundingClientRect();
                const sidebarRect = this.getBoundingClientRect();
                sessionStorage.setItem('sidebar-scroll-offset', clientRect.top - sidebarRect.top);
            }
        }, { passive: true });
        const sidebarScrollOffset = sessionStorage.getItem('sidebar-scroll-offset');
        sessionStorage.removeItem('sidebar-scroll-offset');
        if (sidebarScrollOffset !== null) {
            // preserve sidebar scroll position when navigating via links within sidebar
            const activeSection = this.querySelector('.active');
            if (activeSection) {
                const clientRect = activeSection.getBoundingClientRect();
                const sidebarRect = this.getBoundingClientRect();
                const currentOffset = clientRect.top - sidebarRect.top;
                this.scrollTop += currentOffset - parseFloat(sidebarScrollOffset);
            }
        } else {
            // scroll sidebar to current active section when navigating via
            // 'next/previous chapter' buttons
            const activeSection = document.querySelector('#mdbook-sidebar .active');
            if (activeSection) {
                activeSection.scrollIntoView({ block: 'center' });
            }
        }
        // Toggle buttons
        const sidebarAnchorToggles = document.querySelectorAll('.chapter-fold-toggle');
        function toggleSection(ev) {
            ev.currentTarget.parentElement.parentElement.classList.toggle('expanded');
        }
        Array.from(sidebarAnchorToggles).forEach(el => {
            el.addEventListener('click', toggleSection);
        });
    }
}
window.customElements.define('mdbook-sidebar-scrollbox', MDBookSidebarScrollbox);


// ---------------------------------------------------------------------------
// Support for dynamically adding headers to the sidebar.

(function() {
    // This is used to detect which direction the page has scrolled since the
    // last scroll event.
    let lastKnownScrollPosition = 0;
    // This is the threshold in px from the top of the screen where it will
    // consider a header the "current" header when scrolling down.
    const defaultDownThreshold = 150;
    // Same as defaultDownThreshold, except when scrolling up.
    const defaultUpThreshold = 300;
    // The threshold is a virtual horizontal line on the screen where it
    // considers the "current" header to be above the line. The threshold is
    // modified dynamically to handle headers that are near the bottom of the
    // screen, and to slightly offset the behavior when scrolling up vs down.
    let threshold = defaultDownThreshold;
    // This is used to disable updates while scrolling. This is needed when
    // clicking the header in the sidebar, which triggers a scroll event. It
    // is somewhat finicky to detect when the scroll has finished, so this
    // uses a relatively dumb system of disabling scroll updates for a short
    // time after the click.
    let disableScroll = false;
    // Array of header elements on the page.
    let headers;
    // Array of li elements that are initially collapsed headers in the sidebar.
    // I'm not sure why eslint seems to have a false positive here.
    // eslint-disable-next-line prefer-const
    let headerToggles = [];
    // This is a debugging tool for the threshold which you can enable in the console.
    let thresholdDebug = false;

    // Updates the threshold based on the scroll position.
    function updateThreshold() {
        const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
        const windowHeight = window.innerHeight;
        const documentHeight = document.documentElement.scrollHeight;

        // The number of pixels below the viewport, at most documentHeight.
        // This is used to push the threshold down to the bottom of the page
        // as the user scrolls towards the bottom.
        const pixelsBelow = Math.max(0, documentHeight - (scrollTop + windowHeight));
        // The number of pixels above the viewport, at least defaultDownThreshold.
        // Similar to pixelsBelow, this is used to push the threshold back towards
        // the top when reaching the top of the page.
        const pixelsAbove = Math.max(0, defaultDownThreshold - scrollTop);
        // How much the threshold should be offset once it gets close to the
        // bottom of the page.
        const bottomAdd = Math.max(0, windowHeight - pixelsBelow - defaultDownThreshold);
        let adjustedBottomAdd = bottomAdd;

        // Adjusts bottomAdd for a small document. The calculation above
        // assumes the document is at least twice the windowheight in size. If
        // it is less than that, then bottomAdd needs to be shrunk
        // proportional to the difference in size.
        if (documentHeight < windowHeight * 2) {
            const maxPixelsBelow = documentHeight - windowHeight;
            const t = 1 - pixelsBelow / Math.max(1, maxPixelsBelow);
            const clamp = Math.max(0, Math.min(1, t));
            adjustedBottomAdd *= clamp;
        }

        let scrollingDown = true;
        if (scrollTop < lastKnownScrollPosition) {
            scrollingDown = false;
        }

        if (scrollingDown) {
            // When scrolling down, move the threshold up towards the default
            // downwards threshold position. If near the bottom of the page,
            // adjustedBottomAdd will offset the threshold towards the bottom
            // of the page.
            const amountScrolledDown = scrollTop - lastKnownScrollPosition;
            const adjustedDefault = defaultDownThreshold + adjustedBottomAdd;
            threshold = Math.max(adjustedDefault, threshold - amountScrolledDown);
        } else {
            // When scrolling up, move the threshold down towards the default
            // upwards threshold position. If near the bottom of the page,
            // quickly transition the threshold back up where it normally
            // belongs.
            const amountScrolledUp = lastKnownScrollPosition - scrollTop;
            const adjustedDefault = defaultUpThreshold - pixelsAbove
                + Math.max(0, adjustedBottomAdd - defaultDownThreshold);
            threshold = Math.min(adjustedDefault, threshold + amountScrolledUp);
        }

        if (documentHeight <= windowHeight) {
            threshold = 0;
        }

        if (thresholdDebug) {
            const id = 'mdbook-threshold-debug-data';
            let data = document.getElementById(id);
            if (data === null) {
                data = document.createElement('div');
                data.id = id;
                data.style.cssText = `
                    position: fixed;
                    top: 50px;
                    right: 10px;
                    background-color: 0xeeeeee;
                    z-index: 9999;
                    pointer-events: none;
                `;
                document.body.appendChild(data);
            }
            data.innerHTML = `
                <table>
                  <tr><td>documentHeight</td><td>${documentHeight.toFixed(1)}</td></tr>
                  <tr><td>windowHeight</td><td>${windowHeight.toFixed(1)}</td></tr>
                  <tr><td>scrollTop</td><td>${scrollTop.toFixed(1)}</td></tr>
                  <tr><td>pixelsAbove</td><td>${pixelsAbove.toFixed(1)}</td></tr>
                  <tr><td>pixelsBelow</td><td>${pixelsBelow.toFixed(1)}</td></tr>
                  <tr><td>bottomAdd</td><td>${bottomAdd.toFixed(1)}</td></tr>
                  <tr><td>adjustedBottomAdd</td><td>${adjustedBottomAdd.toFixed(1)}</td></tr>
                  <tr><td>scrollingDown</td><td>${scrollingDown}</td></tr>
                  <tr><td>threshold</td><td>${threshold.toFixed(1)}</td></tr>
                </table>
            `;
            drawDebugLine();
        }

        lastKnownScrollPosition = scrollTop;
    }

    function drawDebugLine() {
        if (!document.body) {
            return;
        }
        const id = 'mdbook-threshold-debug-line';
        const existingLine = document.getElementById(id);
        if (existingLine) {
            existingLine.remove();
        }
        const line = document.createElement('div');
        line.id = id;
        line.style.cssText = `
            position: fixed;
            top: ${threshold}px;
            left: 0;
            width: 100vw;
            height: 2px;
            background-color: red;
            z-index: 9999;
            pointer-events: none;
        `;
        document.body.appendChild(line);
    }

    function mdbookEnableThresholdDebug() {
        thresholdDebug = true;
        updateThreshold();
        drawDebugLine();
    }

    window.mdbookEnableThresholdDebug = mdbookEnableThresholdDebug;

    // Updates which headers in the sidebar should be expanded. If the current
    // header is inside a collapsed group, then it, and all its parents should
    // be expanded.
    function updateHeaderExpanded(currentA) {
        // Add expanded to all header-item li ancestors.
        let current = currentA.parentElement;
        while (current) {
            if (current.tagName === 'LI' && current.classList.contains('header-item')) {
                current.classList.add('expanded');
            }
            current = current.parentElement;
        }
    }

    // Updates which header is marked as the "current" header in the sidebar.
    // This is done with a virtual Y threshold, where headers at or below
    // that line will be considered the current one.
    function updateCurrentHeader() {
        if (!headers || !headers.length) {
            return;
        }

        // Reset the classes, which will be rebuilt below.
        const els = document.getElementsByClassName('current-header');
        for (const el of els) {
            el.classList.remove('current-header');
        }
        for (const toggle of headerToggles) {
            toggle.classList.remove('expanded');
        }

        // Find the last header that is above the threshold.
        let lastHeader = null;
        for (const header of headers) {
            const rect = header.getBoundingClientRect();
            if (rect.top <= threshold) {
                lastHeader = header;
            } else {
                break;
            }
        }
        if (lastHeader === null) {
            lastHeader = headers[0];
            const rect = lastHeader.getBoundingClientRect();
            const windowHeight = window.innerHeight;
            if (rect.top >= windowHeight) {
                return;
            }
        }

        // Get the anchor in the summary.
        const href = '#' + lastHeader.id;
        const a = [...document.querySelectorAll('.header-in-summary')]
            .find(element => element.getAttribute('href') === href);
        if (!a) {
            return;
        }

        a.classList.add('current-header');

        updateHeaderExpanded(a);
    }

    // Updates which header is "current" based on the threshold line.
    function reloadCurrentHeader() {
        if (disableScroll) {
            return;
        }
        updateThreshold();
        updateCurrentHeader();
    }


    // When clicking on a header in the sidebar, this adjusts the threshold so
    // that it is located next to the header. This is so that header becomes
    // "current".
    function headerThresholdClick(event) {
        // See disableScroll description why this is done.
        disableScroll = true;
        setTimeout(() => {
            disableScroll = false;
        }, 100);
        // requestAnimationFrame is used to delay the update of the "current"
        // header until after the scroll is done, and the header is in the new
        // position.
        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                // Closest is needed because if it has child elements like <code>.
                const a = event.target.closest('a');
                const href = a.getAttribute('href');
                const targetId = href.substring(1);
                const targetElement = document.getElementById(targetId);
                if (targetElement) {
                    threshold = targetElement.getBoundingClientRect().bottom;
                    updateCurrentHeader();
                }
            });
        });
    }

    // Takes the nodes from the given head and copies them over to the
    // destination, along with some filtering.
    function filterHeader(source, dest) {
        const clone = source.cloneNode(true);
        clone.querySelectorAll('mark').forEach(mark => {
            mark.replaceWith(...mark.childNodes);
        });
        dest.append(...clone.childNodes);
    }

    // Scans page for headers and adds them to the sidebar.
    document.addEventListener('DOMContentLoaded', function() {
        const activeSection = document.querySelector('#mdbook-sidebar .active');
        if (activeSection === null) {
            return;
        }

        const main = document.getElementsByTagName('main')[0];
        headers = Array.from(main.querySelectorAll('h2, h3, h4, h5, h6'))
            .filter(h => h.id !== '' && h.children.length && h.children[0].tagName === 'A');

        if (headers.length === 0) {
            return;
        }

        // Build a tree of headers in the sidebar.

        const stack = [];

        const firstLevel = parseInt(headers[0].tagName.charAt(1));
        for (let i = 1; i < firstLevel; i++) {
            const ol = document.createElement('ol');
            ol.classList.add('section');
            if (stack.length > 0) {
                stack[stack.length - 1].ol.appendChild(ol);
            }
            stack.push({level: i + 1, ol: ol});
        }

        // The level where it will start folding deeply nested headers.
        const foldLevel = 3;

        for (let i = 0; i < headers.length; i++) {
            const header = headers[i];
            const level = parseInt(header.tagName.charAt(1));

            const currentLevel = stack[stack.length - 1].level;
            if (level > currentLevel) {
                // Begin nesting to this level.
                for (let nextLevel = currentLevel + 1; nextLevel <= level; nextLevel++) {
                    const ol = document.createElement('ol');
                    ol.classList.add('section');
                    const last = stack[stack.length - 1];
                    const lastChild = last.ol.lastChild;
                    // Handle the case where jumping more than one nesting
                    // level, which doesn't have a list item to place this new
                    // list inside of.
                    if (lastChild) {
                        lastChild.appendChild(ol);
                    } else {
                        last.ol.appendChild(ol);
                    }
                    stack.push({level: nextLevel, ol: ol});
                }
            } else if (level < currentLevel) {
                while (stack.length > 1 && stack[stack.length - 1].level > level) {
                    stack.pop();
                }
            }

            const li = document.createElement('li');
            li.classList.add('header-item');
            li.classList.add('expanded');
            if (level < foldLevel) {
                li.classList.add('expanded');
            }
            const span = document.createElement('span');
            span.classList.add('chapter-link-wrapper');
            const a = document.createElement('a');
            span.appendChild(a);
            a.href = '#' + header.id;
            a.classList.add('header-in-summary');
            filterHeader(header.children[0], a);
            a.addEventListener('click', headerThresholdClick);
            const nextHeader = headers[i + 1];
            if (nextHeader !== undefined) {
                const nextLevel = parseInt(nextHeader.tagName.charAt(1));
                if (nextLevel > level && level >= foldLevel) {
                    const toggle = document.createElement('a');
                    toggle.classList.add('chapter-fold-toggle');
                    toggle.classList.add('header-toggle');
                    toggle.addEventListener('click', () => {
                        li.classList.toggle('expanded');
                    });
                    const toggleDiv = document.createElement('div');
                    toggleDiv.textContent = '❱';
                    toggle.appendChild(toggleDiv);
                    span.appendChild(toggle);
                    headerToggles.push(li);
                }
            }
            li.appendChild(span);

            const currentParent = stack[stack.length - 1];
            currentParent.ol.appendChild(li);
        }

        const onThisPage = document.createElement('div');
        onThisPage.classList.add('on-this-page');
        onThisPage.append(stack[0].ol);
        const activeItemSpan = activeSection.parentElement;
        activeItemSpan.after(onThisPage);
    });

    document.addEventListener('DOMContentLoaded', reloadCurrentHeader);
    document.addEventListener('scroll', reloadCurrentHeader, { passive: true });
})();

