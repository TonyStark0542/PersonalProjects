document.addEventListener("DOMContentLoaded", function () {
    // Function to handle form submission
    function handleFormSubmit(event) {
        event.preventDefault(); // Prevent the default form submission

        // Get the user's input
        const name = document.getElementById("name").value;
        const email = document.getElementById("email").value;
        const message = document.getElementById("message").value;

        // You can replace this with your preferred way of handling form data, like sending it to a server.
        // For this example, we'll simply display the user's input in the console.
        console.log("Name: " + name);
        console.log("Email: " + email);
        console.log("Message: " + message);

        // Optionally, you can show a confirmation message to the user or redirect them to a thank-you page.
    }

    // Add a submit event listener to the form
    const contactForm = document.getElementById("contact-form");
    contactForm.addEventListener("submit", handleFormSubmit);
});