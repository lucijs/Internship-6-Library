--ime, prezime, spol, ime države i  prosječna plaća u toj državi svakom autoru
SELECT FirstName AS Ime, LastName AS Prezime, Gender AS Spol, Name AS Država, AverageSalary AS Plaća FROM Authors a
JOIN Countries c ON c.Id = a.CountryId;

--naziv i datum objave svake znanstvene knjige zajedno s imenima glavnih autora koji su na njoj radili, 
--pri čemu imena autora moraju biti u jednoj ćeliji i u obliku Prezime, I.; npr. Puljak, I.; Godinović,N.
SELECT Name, ReleaseDate, STRING_AGG(LastName||', '||SUBSTRING(FirstName FROM 1 FOR 1)||'.', ', ' )FROM  Books b
JOIN AuthorBooks ab ON ab.BookId = b.Id
JOIN Authors a ON a.Id = ab.AuthorId
WHERE b.Type = 'Znanstvena' AND ab.Type = 'Main'
GROUP BY Name, ReleaseDate;

--sve kombinacije (naslova) knjiga i posudbi istih u prosincu 2023.; u slučaju da neka nije ni jednom posuđena u tom 
--periodu, prikaži je samo jednom (a na mjestu posudbe neka piše null)
SELECT Name, LendDate FROM Books b
LEFT JOIN UserBooks ub ON b.Id = ub.BookId AND EXTRACT(MONTH FROM LendDate) = 12 AND EXTRACT(YEAR FROM LendDate) = 2023
ORDER BY LendDate

--top 3 knjižnice s najviše primjeraka knjiga
SELECT l.Name, COUNT(b.Id) AS Number FROM Libraries l
JOIN Books b ON b.LibraryId = l.Id
GROUP BY l.Name
ORDER BY Number DESC
LIMIT 3

--po svakoj knjizi broj ljudi koji su je pročitali (korisnika koji posudili bar jednom)
SELECT b.Name, COUNT (ub.Id) FROM Books b
JOIN UserBooks ub On ub.BookId = b.Id
GROUP BY b.Name

--imena svih korisnika koji imaju trenutno posuđenu knjigu
SELECT u.Name FROM Users u
JOIN UserBooks ub ON u.Id = ub.UserId
WHERE LendDate < CURRENT_DATE AND ReturnDate > CURRENT_DATE

--sve autore kojima je bar jedna od knjiga izašla između 2019. i 2022.
SELECT a.FirstName ||' '|| a.LastName FROM Authors a
JOIN AuthorBooks ab ON ab.AuthorId = a.Id 
JOIN Books b ON b.Id = ab.BookId AND EXTRACT(YEAR FROM ReleaseDate) BETWEEN 2018 AND 2022


--ime države i broj umjetničkih knjiga po svakoj (ako su dva autora iz iste države, računa se kao jedna knjiga),
--gdje su države sortirane po broju živih autora od najveće ka najmanjoj 
SELECT c.Name, 
	COUNT(b.Id),
	(SELECT COUNT(*) FROM Authors a2
		 	WHERE a2.CountryId = c.Id AND EXTRACT(YEARS FROM AGE(CURRENT_DATE, DateOfBirth))<90) AS NumberOfAliveAuthors
FROM Countries c
JOIN Authors a ON c.Id = a.CountryId
JOIN AuthorBooks ab ON ab.AuthorId = a.Id 
JOIN Books b ON ab.BookId = b.Id AND b.Type = 'Umjetnička'
GROUP BY c.Name, c.Id
ORDER BY NumberOfAliveAuthors DESC

--po svakoj kombinaciji autora i žanra (ukoliko postoji) broj posudbi knjiga tog autora u tom žanru
SELECT a.FirstName || ' ' || a.LastName, b.Type, COUNT(ab.BookId)  FROM Authors a
JOIN AuthorBooks ab ON a.Id = ab.AuthorId
JOIN Books b ON b.Id = ab.BookId
GROUP BY a.FirstName,a.LastName, b.Type


--po svakom članu koliko trenutno duguje zbog kašnjenja; u slučaju da ne duguje ispiši “ČISTO”
SELECT Name,
	COALESCE(CAST(
		(SELECT CheckDebt(u2.Id) 
		 	FROM Users u2 WHERE CheckDebt(Id)!=0.0 AND u1.Id = u2.Id )AS VARCHAR), 'Čisto') 
FROM Users u1

--autora i ime prve objavljene knjige istog
SELECT a.FirstName, a.LastName,(SELECT b.Name FROM Books b 
							   	JOIN AuthorBooks ab ON b.Id = ab.BookId
							    WHERE ab.AuthorId = a.Id
							   ORDER BY b.ReleaseDate,b.Name
							   LIMIT 1) FROM Authors a
								 
--državu i ime druge objavljene knjige iste
SELECT c.Name, (SELECT b.Name FROM Books b JOIN AuthorBooks ab ON ab.BookId = b.Id
	   							 JOIN Authors a ON a.Id = ab.AuthorId
	   							 WHERE a.CountryId = c.Id
	   							 ORDER BY b.ReleaseDate,b.Name
	   							LIMIT 1 OFFSET 1) FROM Countries c



--knjige i broj aktivnih posudbi
SELECT b.Name, COUNT(ub.Id) FROM Books b
JOIN UserBooks ub ON ub.BookId = b.Id
GROUP BY b.Name


--prosječan broj posudbi po primjerku knjige po svakoj državi
SELECT b.Name, AVG(b.Id), c.Name FROM Countries c
JOIN Authors a ON a.CountryId =c.Id
JOIN AuthorBooks ab ON ab.AuthorId = a.Id
JOIN Books b ON b.Id = ab.BookId
GROUP BY b.Name,c.Name

--broj autora (koji su objavili više od 5 knjiga) po struci, desetljeću rođenja i spolu; u slučaju da je broj autora manji od 10,
--ne prikazuj kategoriju; poredaj prikaz po desetljeću rođenja


--10 najbogatijih autora, ako po svakoj knjizi dobije brojPrimjerakabrojAutoraPoKnjizi €
