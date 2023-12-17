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
	Available BOOL
);

ALTER TABLE Books
	ADD CONSTRAINT BookTyps CHECK(Type in ('Lektira','Umjetnička','Znanstvena','Biografija','Stručna'));
	
CREATE TABLE AuthorBooks(
	Id SERIAL PRIMARY KEY,
	BookId INT REFERENCES Books(Id),
	AuthorId INT REFERENCES Authors(Id),
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
	Extend BOOL
);
---------------------------------------------------------
CREATE OR REPLACE PROCEDURE LendABook(BookId INT, UserId Int)
LANGUAGE plpgsql
AS $$
BEGIN
	IF (SELECT NumberOfLendedBooks FROM Users WHERE Id=UserId)<3 AND (SELECT Available FROM Books WHERE Id = BookId) = true 
		AND (SELECT LibraryId FROM Users WHERE Id=UserId)=(SELECT LibraryId FROM Books WHERE Id = BookId) THEN
		INSERT INTO UserBoooks(BookId,UserId,LendDate,ReturnDate) VALUES(BookId,UserId,CURRENT_DATE,CURRENT_DATE + INTERVAL '20 days'); 
		UPDATE Books
		SET Available =false
		WHERE Id = BookId;
		UPDATE Users
		SET NumberOfBooksLended = NumberOfBooksLended +1
		WHERE Id = UserId;		
	END IF;
END;
$$
---------------------------------------------------------
CREATE PROCEDURE ExtendTheLending(BId INT, UId Int)
LANGUAGE plpgsql
AS $$
BEGIN
	IF EXISTS(SELECT 1 FROM UserBooks WHERE BookId = BId AND UserId = UId) THEN
		UPDATE UserBooks 
		SET ReturnDate = ReturnDate + INTERVAL '40 days', Extend = false
		WHERE UserId = UId and BookId = BId;
	END IF;
END;
$$
---------------------------------------------------------
CREATE OR REPLACE PROCEDURE CheckDebt(UId INT)
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
          				IF (SELECT Type FROM Books WHERE Id = BookId) = 'Lektira' THEN
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