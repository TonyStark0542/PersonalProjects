import os
from flask import Flask, jsonify, request
from flask_cors import CORS  # You must install this: pip install flask-cors
from pymongo import MongoClient
from bson.objectid import ObjectId

app = Flask(__name__)
# This is the "Secret Sauce" that allows your frontend to talk to your backend
CORS(app) 

# Use an environment variable for Mongo so it works on your Mac and in Kubernetes
mongo_uri = os.environ.get("MONGO_URI", "mongodb://mongodb-service:27017")
client = MongoClient(mongo_uri)
db = client['bookstore']

# The Health Check
@app.route('/')
def health_check():
    return "OK", 200

# TIER 2 API: Get all books
# Used by js/main.js
@app.route('/api/books', methods=['GET'])
def get_all_books():
    try:
        books_cursor = db['books'].find()
        books_list = []
        for book in books_cursor:
            book['_id'] = str(book['_id'])
            books_list.append(book)
        return jsonify(books_list)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# TIER 2 API: Get a single book's details
# Used by js/book-detail.js
@app.route('/api/books/<string:book_id>', methods=['GET'])
def get_book_details(book_id):
    try:
        book = db['books'].find_one({'_id': ObjectId(book_id)})
        if book:
            book['_id'] = str(book['_id'])
            return jsonify(book)
        return jsonify({"error": "Book not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# TIER 2 API: Get books by category
# Used by js/category.js
@app.route('/api/books/category/<string:category_name>', methods=['GET'])
def get_books_by_category(category_name):
    try:
        books_cursor = db['books'].find({"category": category_name})
        books_list = []
        for book in books_cursor:
            book['_id'] = str(book['_id'])
            books_list.append(book)
        return jsonify(books_list)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    # We set host='0.0.0.0' so it's reachable inside a Docker container
    app.run(debug=True, host='0.0.0.0', port=5000)

# ============================================================================================

# Example API route to retrieve a single book by ID
# @app.route('/books/<string:book_id>', methods=['GET'])
# def get_book(book_id):
#     try:
#         # Fetch a single book from the 'books' collection
#         book = db['books'].find_one({'_id': ObjectId(book_id)})

#         if book is None:
#             return jsonify({"error": "Book not found"}), 404

#         # Convert ObjectId to string to avoid BSON format issues
#         book['_id'] = str(book['_id'])

#         # Return the JSON response
#         return jsonify(book)
#     except Exception as e:
#         return jsonify({"error": str(e)}), 500

# ============================================================================================


# ============================================================================================

# ============================================================================================

# Example model for books collection
# class Book:
#     def __init__(self, title, author, publisher, price, front_image, back_image):
#         self.title = title
#         self.author = author
#         self.publisher = publisher
#         self.price = price
#         self.front_image = front_image
#         self.back_image = back_image

# ============================================================================================


# ============================================================================================

# Example API route to retrieve all books
# @app.route('/books', methods=['GET'])
# def get_books():
#     try:
#         # Fetch all books from the 'books' collection
#         books_cursor = db['books'].find()

#         # Convert the cursor to a list of dictionaries
#         books_list = list(books_cursor)

#         # Optional: You can manually remove ObjectId to avoid BSON format issues
#         for book in books_list:
#             book['_id'] = str(book['_id'])  # Convert ObjectId to string

#         # Return the JSON response
#         return jsonify(books_list)
#     except Exception as e:
#         return jsonify({"error": str(e)}), 500

# ============================================================================================

# Example API route to add a new book
# @app.route('/books', methods=['POST'])
# def add_book():
    # books_collection = db.books  # Replace 'books' with your collection name

    # Sample data from request (assuming JSON input)
    # data = request.json

    # # for Book class we need this data:
    # title = data['title']
    # author = data['author']
    # publisher = data['publisher']
    # price = data['price']
    # front_image = data['front_image']
    # back_image = data['back_image']

    # # Create a new Book object
    # new_book = Book(title, author, publisher, price, front_image, back_image)

    # # Insert into MongoDB
    # result = books_collection.insert_one(new_book.__dict__)

    # return jsonify({'message': 'Book added successfully', 'id': str(result.inserted_id)})

    # -------------
    # Without Book Class we can do this:
    # Define the structure of the new book document
    # new_book = {
    #     "title": data["title"],
    #     "author": data["author"],
    #     "publisher": data["publisher"],
    #     "price": data["price"],
    #     "cover_image": data["cover_image"]
    # }
    
    # try:
    #     # Insert the new book document into the 'books' collection
    #     result = db['books'].insert_one(new_book)
        
    #     # Return the ID of the newly created book as a response
    #     return jsonify({"_id": str(result.inserted_id)}), 201
    
    # except Exception as e:
    #     # If there's an error, return the error message
    #     return jsonify({"error": str(e)}), 500

# ============================================================================================
