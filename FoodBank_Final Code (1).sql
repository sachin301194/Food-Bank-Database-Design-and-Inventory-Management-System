CREATE DATABASE FoodBankNEW
GO

USE FoodBankNEW
GO
/* ADDRESS TABLE TO STORE Foodbank Addresses*/
CREATE TABLE [ADDRESS]
(
  [AddressID] INT IDENTITY(100,1) NOT NULL,
  [Street] VARCHAR(100) NOT NULL ,
  [City] VARCHAR(20),
  [Zip] INT,
  PRIMARY KEY ([AddressID])
);
SELECT * FROM [ADDRESS]
/* Agency table for agencies providing volunteers and employees*/
CREATE TABLE [AGENCY] (
  [AgencyID]  INT IDENTITY(5000,1) NOT NULL,
  [AgencyName] VARCHAR(50),
  PRIMARY KEY ([AgencyID])
);
SELECT * FROM AGENCY
/*Foodbank Master Table*/
CREATE TABLE [FOODBANK] (
  [FoodbankID] INT IDENTITY(7000,1) NOT NULL,
  [AddressID]  INT REFERENCES dbo.[ADDRESS](AddressID) NOT NULL,
  [Name] VARCHAR(MAX),
  [Funds] MONEY,
  [Status] VARCHAR(10),
  PRIMARY KEY ([FoodbankID])
);
SELECT * FROM [FOODBANK]
/* User Database Table*/
CREATE TABLE [USER]
(
  [UserID] INT IDENTITY(1,1) NOT NULL,
  [FoodbankID] INT REFERENCES dbo.FOODBANK(FoodbankID) NOT NULL,
  [Email] VARCHAR(50),
  [Password] VARCHAR(250),
  [Month] INT,
  [Year] INT,
  [Phone] CHAR(10),
  [SSN] NVARCHAR(20),
  [DOB] DATE 
  CONSTRAINT [PK_User_UserID] PRIMARY KEY CLUSTERED (UserID ASC)
);
SELECT * FROM [USER]
/*Table to store user household Information*/
CREATE TABLE [HOUSEHOLD] (
  [HouseholdID]  INT IDENTITY(2000,1) NOT NULL,
  [UserID] INT REFERENCES [USER]([UserID]) NOT NULL,
  [FirstName] VARCHAR(20),
  [LastName] VARCHAR(20),
  [Income] MONEY,
  DOB VARCHAR(10),
  Age AS DATEDIFF(hour,DOB,GETDATE())/8766,
  PRIMARY KEY ([HouseholdID])
);
SELECT * FROM [HOUSEHOLD]



/* Provide Column level Encryption of password column in User Table*/
-- Create DATABASE MASTER KEY
CREATE MASTER KEY
ENCRYPTION BY PASSWORD = 'P@sswOrd';

CREATE CERTIFICATE TestCertificate
WITH SUBJECT = 'FoodBank Certificate',
EXPIRY_DATE = '2026-10-31';

CREATE SYMMETRIC KEY TestSymmetricKey
WITH ALGORITHM = AES_128
ENCRYPTION BY CERTIFICATE TestCertificate;

OPEN SYMMETRIC KEY TestSymmetricKey
DECRYPTION BY CERTIFICATE TestCertificate;

UPDATE [USER] 
SET [USER].[Password] = EncryptByKey(Key_GUID('TestSymmetricKey')  
    ,  CONVERT( varbinary  
    , [USER].[Password]));  
GO 



OPEN SYMMETRIC KEY TestSymmetricKey  
DECRYPTION BY CERTIFICATE TestCertificate;  
GO 
/*View Decrypted Password*/
SELECT [Password]   
    AS 'Encrypted Password', CONVERT(varchar,  
    DecryptByKey([Password]))  
    AS 'Decrypted Password' FROM dbo.[USER];  
GO  
/* Table to store employee Information*/
CREATE TABLE [EMPLOYEES] (
  [EmployeeID] INT IDENTITY(6000,1) NOT NULL,
  AgencyID INT REFERENCES dbo.AGENCY(AgencyID),
  [FoodbankID] INT REFERENCES dbo.FOODBANK(FoodbankID) NOT NULL,
  [FirstName] VARCHAR(50),
  [LastName] VARCHAR(50),
  [Type] CHAR(10),
       /*COLUMN LEVEL CONSTRAINTS*/
  CHECK ([EMPLOYEES].[TYPE] IN ('Employee','Volunteer')),
  PRIMARY KEY ([EmployeeID])
);
/* Catalog of food products in the inventory*/
CREATE TABLE [INVENTORY] (
  [FoodItemID] INT IDENTITY(6000,1) NOT NULL,
  [Name] NVARCHAR(50),
  [Description] NVARCHAR(MAX),
  PRIMARY KEY ([FoodItemID])
);
/* Table containing foodbank inventory data, amount and the foodbank Information of which the inventory is a part of*/
CREATE TABLE [INVENTORY_LOCATION]
(
	[InventoryID] INT IDENTITY(700,1) PRIMARY KEY ,
	[FoodItemID] INT REFERENCES dbo.[INVENTORY]([FoodItemId]),
	[FoodbankID] INT REFERENCES dbo.FOODBANK(FoodBankID), 
	[Quantity] INT ,
	[Weight] FLOAT,
	[Threshold] INT,
);
/* Order Information Table*/

CREATE TABLE [ORDERS] 
(
  [OrderID] INT IDENTITY(300,1) NOT NULL,
  [InventoryID] INT REFERENCES dbo.[INVENTORY_LOCATION](InventoryID) NOT NULL,
  [Quantity] INT,
  [Weight] FLOAT,
  [DeliveryDate] DATE,
  [Delivered?] VARCHAR(3),
  PRIMARY KEY ([OrderID])
);
/*Donation Information Table*/
CREATE TABLE [DONATIONS] 
(
  [DonationID] INT IDENTITY(200,1) NOT NULL,
  [InventoryID] INT REFERENCES dbo.[INVENTORY_LOCATION](InventoryId) NOT NULL,
  [Quantity] INT,
  [Weight] FLOAT,
  PRIMARY KEY ([DonationID])
);
/* Table to maintain record of each and every transaction i.e. Donation or Orders to the foodbank inventory*/

CREATE TABLE [TRANSACTION HEADER] (
  [TransactionHeaderID] INT IDENTITY(8000,1) NOT NULL,
  [FoodbankID] INT REFERENCES dbo.FOODBANK(FoodBankID) NOT NULL,
  [DonationID] INT REFERENCES dbo.DONATIONS(DonationID),
  [OrderID] INT,
  [FoodbankTXTypeCode] VARCHAR(10),
     /*TABLE LEVEL CONSTRAINTS*/
  CHECK ([TRANSACTION HEADER].[FoodbankTXTypeCode] IN ('Donation','Order')),
  [TXDate] DATE,
  [ReceiptID] INT,
  PRIMARY KEY ([TransactionHeaderID])
);
ALTER TABLE [TRANSACTION HEADER]
ADD CONSTRAINT FK_PersonOrder
FOREIGN KEY (OrderID) REFERENCES Orders(OrderID);
/* Table to maintain transaction details i.e. Unit Price, Quantity Weight and calculate the Total price based on QUantity and weight and unit price*/
CREATE TABLE [FOODBANK_TRANSACTION]
(
  [FoodbankTxID] INT IDENTITY(9000,1) NOT NULL,
  [TransactionHeaderID] INT REFERENCES dbo.[TRANSACTION HEADER](TransactionHeaderID) NOT NULL ,
  [InventoryID] INT REFERENCES dbo.INVENTORY_LOCATION(InventoryID) NOT NULL,
  [UnitPrice] MONEY,
  [Quantity] INT,
  [Weight] FLOAT,
  PRIMARY KEY ([FoodbankTxID])
);


/* RESET seed for identity column*/
--DBCC CHECKIDENT([FOODBANK_TRANSACTION], RESEED, 8999);
/* Table to maintain Fund Raiser Activities*/
CREATE TABLE [FUND_RAISER] 
(
  [ProgramID] Int IDENTITY(1000,1) NOT NULL,
  [FoodBankID] INT REFERENCES dbo.FOODBANK([FoodBankID])  NOT NULL ,
  [Name] VARCHAR(50),
  [FundsCollected] MONEY,
  PRIMARY KEY ([ProgramID])
);

-- Function to calculate Line Price
CREATE FUNCTION fn_CalcLinePrice(@FoodbankTxID INT)
RETURNS MONEY
AS
	BEGIN
      DECLARE @lineAmount MONEY
	  DECLARE @weight FLOAT= (
	  SELECT Weight FROM FOODBANK_TRANSACTION
	  WHERE FoodbankTxID = @FoodbankTxID)
	  IF @weight IS NULL
		SET @lineAmount = (SELECT (Quantity * UnitPrice) 
							FROM FOODBANK_TRANSACTION 
							WHERE FoodbankTxID = @FoodbankTxID);
	  ELSE 
		SET @lineAmount = (SELECT (Weight * UnitPrice) 
							FROM FOODBANK_TRANSACTION 
							WHERE FoodbankTxID = @FoodbankTxID);
	  RETURN @lineAmount;	
	END

-- Add a computed column to FOODBANK_TRANSACTION

ALTER TABLE FOODBANK_TRANSACTION
ADD LinePrice AS (dbo.fn_CalcLinePrice(FoodbankTxID));

SELECT * FROM FOODBANK_TRANSACTION

-- Allow Orders only if the quantity or the weight is there in Inventory!
CREATE FUNCTION AllowOrders (@InventoryID int, @Quantity int, @Weight float)
RETURNS smallint
AS
BEGIN
	IF @Weight IS NULL
		BEGIN
			DECLARE @invQuantity INT = (SELECT Quantity FROM INVENTORY_LOCATION
										WHERE InventoryId = @InventoryID);
			IF @Quantity > @invQuantity
				Return 0;
		END;
	ELSE 
		BEGIN
			DECLARE @invWeight INT = (SELECT Weight FROM INVENTORY_LOCATION
										WHERE InventoryId = @InventoryID);
			IF @Weight > @invWeight
				Return 0;
		END;
	RETURN 1;
END;

ALTER TABLE ORDERS ADD CONSTRAINT BanOrders CHECK (dbo.AllowOrders(InventoryID, Quantity, Weight) != 0);
-- Allow Donations only if the FoodBank is active!
CREATE FUNCTION AllowDonation (@InventoryID int)
RETURNS smallint
AS
BEGIN
   DECLARE @Count smallint=0;
   SELECT @Count = (SELECT COUNT(*) FROM INVENTORY_LOCATION il
							JOIN FOODBANK fb
							ON fb.FoodbankID = il.FoodbankID
							WHERE il.InventoryID = @InventoryID
							AND fb.Status = 'Active') ;
   RETURN @Count;
END;

ALTER TABLE DONATIONS ADD CONSTRAINT BanDonation CHECK (dbo.AllowDonation(InventoryID) != 0);

---------------------------------------------------VIEWS-----------------------------------------------------
GO;
-- View to get the total funds raised by a particular foodbank!
CREATE VIEW vFoodBankFunds
AS
SELECT fb.Name AS 'Food Bank', SUM(FundsCollected) AS 'Tota Funds Collected' 
FROM dbo.FUND_RAISER fr
JOIN FOODBANK fb
ON fr.FoodBankID = fb.FoodbankID
GROUP BY fb.Name;
GO;

-- Details of all the Active FoodBanks
CREATE VIEW vDisplayInActiveFoodBanks
AS
SELECT fb.Name AS 'Food Bank',  CONCAT(addr.Street,', ', addr.City,', ', addr.Zip) AS 'Address', fb.Funds AS 'Total Funds Raised'
FROM FoodBank fb
JOIN Address addr
ON fb.AddressID = addr.AddressID
WHERE fb.Status = 'Inactive';
GO;

-- Number of Users served by a FoodBank
CREATE VIEW vUsersServed
AS
WITH TEMP
AS
(SELECT UserID, COUNT(HouseholdID) AS 'Total_Members' FROM HOUSEHOLD
GROUP BY UserID)
SELECT fb.Name  AS 'Food Bank', COUNT(us.UserID) AS 'Households served', SUM(Total_Members) AS 'Total Users Served'
FROM dbo.[USER] us
JOIN FoodBank fb
ON us.FoodbankID = fb.FoodbankID
JOIN TEMP t
ON t.UserID = us.UserID
GROUP BY fb.Name;
GO;

-- Total Food Order Amount(Monetary Value) by a foodbank!
CREATE VIEW vTotalOrderAmount
AS
SELECT fb.Name AS 'Food Bank',  SUM(LinePrice) AS 'Total Order Amount'
FROM FoodBank fb
JOIN [TRANSACTION HEADER] th
ON fb.FoodbankID = th.FoodbankID
JOIN FOODBANK_TRANSACTION ft
ON ft.TransactionHeaderID = th.TransactionHeaderID
WHERE fb.Status = 'Active'
AND th.OrderID IS NOT NULL
GROUP BY fb.Name, fb.FoodbankID;
GO;

-- Total Items of each Food Item left in Foodbank Inventory
CREATE VIEW vFoodItemsLeft
AS
SELECT foo.Name AS 'Food Bank', inv.Name AS 'Food Item', 
(ISNULL(il.Quantity,0) - ISNULL(SUM(od.Quantity),0) + ISNULL(SUM(do.Quantity),0)) AS [Total Quantity Left], 
(ISNULL(il.Weight,0) - ISNULL(SUM(od.Weight),0) + ISNULL(SUM(do.Weight),0)) AS [Total kgs left]
FROM INVENTORY_LOCATION il
FULL JOIN ORDERS od
ON il.InventoryID = od.InventoryID
FULL JOIN DONATIONS do
ON il.InventoryID = do.InventoryID
JOIN INVENTORY inv
ON inv.FoodItemID = il.FoodItemID
JOIN FOODBANK foo
ON foo.FoodbankID = il.FoodbankID
GROUP BY il.FoodBankID, il.Quantity, il.Weight, inv.Name, foo.Name;
GO;

-- Trigger to add funds to the foodbank total funds if a fund is raised!
CREATE TRIGGER tr_AddFunds
   ON FUND_RAISER
   AFTER INSERT
AS
BEGIN
	  UPDATE FOODBANK SET Funds = (SELECT (fb.Funds + i.FundsCollected) 
									FROM FOODBANK fb
									JOIN INSERTED i
									ON i.FoodBankID = fb.FoodbankID)
		WHERE FoodBankID = (SELECT FoodbankID FROM INSERTED);
END;
GO;




