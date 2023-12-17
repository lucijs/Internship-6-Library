CREATE TABLE Countries(
	Id SERIAL PRIMARY KEY,
	Name VARCHAR NOT NULL,
	Population INT NOT NULL,
	AverageSalary FLOAT
);

CREATE TABLE Authors(
	Id SERIAL PRIMARY KEY,
	FirstName VARCHAR,
	LastName VARCHAR,
	DateOfBirth TIMESTAMP,
	CountryId INT REFERENCES Countries(Id),
	Gender VARCHAR NOT NULL,
	Profession VARCHAR
);

CREATE TABLE Libraries(
	Id SERIAL PRIMARY KEY,
	Name VARCHAR NOT NULL,
	StartTime TIME,
	EndTime TIME,
	CountryId INT REFERENCES Countries(Id)
);

CREATE TABLE Books(
	Id SERIAL PRIMARY KEY,
	Key VARCHAR,
	Name VARCHAR NOT NULL,
	ReleaseDate TIMESTAMP,
	Type VARCHAR NOT NULL,
	LibraryId INT REFERENCES Libraries(Id),
	Available VARCHAR
);

ALTER TABLE Books
	ADD CONSTRAINT BookTyps CHECK(Type in ('Lektira','Umjetnička','Znanstvena','Biografija','Stručna'));
	
CREATE TABLE AuthorBooks(
	BookId INT REFERENCES Books(Id),
	AuthorId INT REFERENCES Authors(Id),
	PRIMARY KEY(BookId,AuthorId),
	Type VARCHAR NOT NULL
);

ALTER TABLE AuthorBooks
	ADD CONSTRAINT TypsOfAuthors CHECK(Type in('Main', 'Secondary'));
	
CREATE TABLE Librarians(
	Id SERIAL PRIMARY KEY,
	Name VARCHAR,
	LibraryId INT REFERENCES Libraries(Id)
);

CREATE TABLE Users(
	Id SERIAL PRIMARY KEY,
	Name VARCHAR,
	LibraryId INT REFERENCES Libraries(Id),
	NumberOfLendedBooks INT NOT NULL,
	UsersDebt FLOAT
);

CREATE TABLE UserBooks(
	Id SERIAL PRIMARY KEY,
	BookId INT REFERENCES Books(Id),
	UserId INT REFERENCES Users(Id),
	LendDate TIMESTAMP,
	ReturnDate TIMESTAMP,
	Extend VARCHAR,
	Returned VARCHAR
);
---------------------------------------------------------
CREATE OR REPLACE PROCEDURE LendABook(BookId INT, UserId Int)
LANGUAGE plpgsql
AS $$
BEGIN
	IF (SELECT NumberOfLendedBooks FROM Users WHERE Id=UserId)<3 AND (SELECT Available FROM Books WHERE Id = BookId) = 'true' 
		AND (SELECT LibraryId FROM Users WHERE Id=UserId)=(SELECT LibraryId FROM Books WHERE Id = BookId) THEN
		INSERT INTO UserBooks(BookId,UserId,LendDate,ReturnDate,Extend,Returned) VALUES(BookId,UserId,CURRENT_DATE,CURRENT_DATE + INTERVAL '20 days','true','false'); 
		UPDATE Books
		SET Available ='false'
		WHERE Id = BookId;
		UPDATE Users
		SET NumberOfBooksLended = NumberOfBooksLended +1
		WHERE Id = UserId;	
	END IF;
END;
$$
---------------------------------------------------------
CREATE OR REPLACE PROCEDURE ExtendTheLending(BId INT, UId Int)
LANGUAGE plpgsql
AS $$
BEGIN
	IF EXISTS(SELECT 1 FROM UserBooks WHERE BookId = BId AND UserId = UId) THEN
		UPDATE UserBooks 
		SET ReturnDate = ReturnDate + INTERVAL '40 days', Extend = 'false'
		WHERE UserId = UId and BookId = BId;
	END IF;
END;
$$
---------------------------------------------------------
CREATE OR REPLACE PROCEDURE ReturnTheBook(BId INT, UId Int)
LANGUAGE plpgsql
AS $$
BEGIN
	IF EXISTS(SELECT 1 FROM UserBooks WHERE BookId = BId AND UserId = UId) THEN
		UPDATE UserBooks 
		SET Returned = 'true'
		WHERE UserId = UId and BookId = BId;
		
		UPDATE Books 
		SET Available = 'true'
		WHERE BookId = BId;
		
		UPDATE Users 
		SET NumberOfBooksLended = NumberOfBooksLended - 1
		WHERE UserId = UId;
	END IF;
END;
$$
---------------------------------------------------------
CREATE OR REPLACE FUNCTION CheckDebt(UId INT)
	RETURNS FLOAT
	LANGUAGE plpgsql
	AS $$
	DECLARE 
		Debt FLOAT;
		Date TIMESTAMP;
	BEGIN
		Debt = 0.0;
		FOR Date IN (SELECT ReturnDate FROM UserBooks WHERE UserId = UId) LOOP
    		IF CURRENT_TIMESTAMP >= Date THEN 
      			WHILE EXTRACT(MONTH FROM CURRENT_DATE) <= EXTRACT(MONTH FROM Date) LOOP
        			IF EXTRACT(MONTH FROM Date) BETWEEN 6 AND 9 THEN
          				IF EXTRACT(DOW FROM Date) IN (0, 6) THEN 
            				Debt := Debt + 0.2;
          				ELSE
            				Debt := Debt + 0.3;
          				END IF;
        			ELSE
          				IF (SELECT Type FROM Books b JOIN UserBooks ub ON b.Id = ub.BookId WHERE ub.UserId=UId and Date = ReturnDate) = 'Lektira' THEN
            				Debt := Debt + 0.5;
          				ELSEIF EXTRACT(DOW FROM Date) IN (0, 6) THEN 
            				Debt := Debt + 0.4;
          				ELSE 
            				Debt := Debt + 0.2;
          				END IF;
        			END IF;
					Date := Date + interval '1 day';
      			END LOOP;
    		END IF;
  		END LOOP;
		
		IF (SELECT Debt FROM Users WHERE Id = UId) != Debt THEN
			UPDATE Users u
			SET UsersDebt = Debt
			WHERE Id = UId;
		END IF;
		RETURN Debt;
	END;
	$$
---------------------------------------------------------
CREATE OR REPLACE FUNCTION add_author()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
BEGIN
	IF NEW.Gender = NULL THEN
		NEW.Gender = 'Nepoznato';
	ELSEIF NEW.Gender = 'Female' THEN
		NEW.Gender = 'Ženski';
	ELSEIF NEW.Gender = 'Male' THEN
		NEW.Gender = 'Muški';
	ELSE
		NEW.Gender = 'Ostalo';
	END IF;
	RETURN NEW;
END; 
$$
--------------------------------------------------------
CREATE TRIGGER add_author
BEFORE INSERT ON  Authors
FOR EACH ROW
EXECUTE FUNCTION add_author();
---------------------------------------------------------
CREATE OR REPLACE FUNCTION lend_a_book()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
BEGIN
	IF (SELECT NumberOfLendedBooks FROM Users WHERE Id=NEW.UserId)>=3 THEN
		RAISE EXCEPTION 'Insert prevented: the user already has 3 books.';
	ELSEIF (SELECT Available FROM Books WHERE Id = NEW.BookId) = 'false' THEN 
		RAISE EXCEPTION 'Insert prevented: the book is unavailable';
	ELSEIF (SELECT LibraryId FROM Users WHERE Id=NEW.UserId)!=(SELECT LibraryId FROM Books WHERE Id = NEW.BookId) THEN
		RAISE EXCEPTION 'Insert prevented: the book and the user are not in the same library';
	ELSE 
		NEW.Extend = 'true';
		NEW.ReturnDate = NEW.LendDate+ INTERVAL '20 days'; 
		CASE WHEN CAST(NEW.Returned AS INT)%2= 0 THEN
				NEW.Returned = 'true';
				CALL ReturnTheBook(NEW.BookId, NEW.UserId);
		 	 WHEN CAST(NEW.Returned AS INT) % 2 = 1 THEN
				NEW.Returned = 'false';
				UPDATE Books
				SET Available ='false'
				WHERE Id = NEW.BookId;
				UPDATE Users
				SET NumberOfLendedBooks = NumberOfLendedBooks +1
				WHERE Id = NEW.UserId;
		END CASE;	
	END IF;
	RETURN NEW;
END; 
$$
--------------------------------------------------------
CREATE TRIGGER lend_a_book
BEFORE INSERT ON  UserBooks
FOR EACH ROW
EXECUTE FUNCTION lend_a_book();
---------------------------------------------------------
CREATE OR REPLACE FUNCTION add_a_book()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
BEGIN
	CASE WHEN CAST(NEW.Type AS INT)%5=0 THEN
			NEW.Type = 'Lektira';
		 WHEN CAST(NEW.Type AS INT)%5=1 THEN
			NEW.Type = 'Umjetnička';
		 WHEN CAST(NEW.Type AS INT)%5=2 THEN
			NEW.Type = 'Znanstvena';
		 WHEN CAST(NEW.Type AS INT)%5=3 THEN
			NEW.Type = 'Biografija';
		 WHEN CAST(NEW.Type AS INT)%5=4 THEN
			NEW.Type = 'Stručna';
	END CASE;
	NEW.Available = 'true';
	RETURN NEW;
END; 
$$
--------------------------------------------------------
CREATE TRIGGER add_a_book
BEFORE INSERT ON  Books
FOR EACH ROW
EXECUTE FUNCTION add_a_book();
---------------------------------------------------------
CREATE OR REPLACE FUNCTION add_AuthorBooks()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
BEGIN
	CASE WHEN CAST(NEW.Type AS INT)%2= 0 THEN
			NEW.Type = 'Main';
		 WHEN CAST(NEW.Type AS INT) % 2 = 1 THEN
			NEW.Type = 'Secondary';
	END CASE;
	RETURN NEW;
END; 
$$
--------------------------------------------------------
CREATE TRIGGER add_AuthorBooks
BEFORE INSERT ON AuthorBooks
FOR EACH ROW
EXECUTE FUNCTION add_AuthorBooks();