


// Hamburger
const hamburger = document.querySelector("#hamburger");
const navMenu = document.querySelector("#nav-menu");
const toTop = document.querySelector("#toTop");


hamburger.addEventListener("click", function () {
    hamburger.classList.toggle("hamburger-active");
    navMenu.classList.toggle("hidden");
    
});



// Navbar Fixed

window.onscroll = function () {
    const header = document.querySelector("header");
    const fixNav = header.offsetTop;

    if (window.pageYOffset > fixNav) {
        header.classList.add("navbar-fix");
        toTop.classList.remove("hidden");
    }
    else {
        header.classList.remove("navbar-fix");
        toTop.classList.add("hidden");
    }
};

// Close klik diluar hamburger 

window.addEventListener('click', function(e){
    if(e.target != navMenu && e.target != hamburger){
        hamburger.classList.remove("hamburger-active");
        navMenu.classList.add("hidden");

    }
});

// dark mode toggle 

const darkToggle = document.querySelector('#dark-toggle');
const html = document.querySelector('html');
const namaImam = document.querySelector('#namaImam');
const desImam = document.querySelector('#desImam');

darkToggle.addEventListener('click', function () {
  if (darkToggle.checked) {
    html.classList.add('dark');
    localStorage.theme = 'dark';
    namaImam.classList.remove("strokeHome");
    desImam.classList.remove("strokeHome");
    
  } else {
    html.classList.remove('dark');
    namaImam.classList.add("strokeHome");
    desImam.classList.add("strokeHome");
    localStorage.theme = 'light';
  }
});