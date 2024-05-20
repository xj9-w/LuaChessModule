local Main = {}
Main.__index = Main

local function GetTeam(Piece)
	return Piece ~= " " and string.lower(Piece) == Piece and "B" or "W"
end

local function FindInTable(Table, Item)
	local Found = {}
	
	for i, Object in Table do
		if Object == Item then
			table.insert(Found, i)
		end
	end
	
	return Found
end

function Main.NewGame()
	local self = {
		["Board"] = {
			{"r", "n", "b", "q", "k", "b", "n", "r"},
			{"p", "p", "p", "p", "p", "p", "p", "p"},
			{" ", " ", " ", " ", " ", " ", " ", " "},
			{" ", " ", " ", " ", " ", " ", " ", " "},
			{" ", " ", " ", " ", " ", " ", " ", " "},
			{" ", " ", " ", " ", " ", " ", " ", " "},
			{"P", "P", "P", "P", "P", "P", "P", "P"},
			{"R", "N", "B", "Q", "K", "B", "N", "R"}
		},
		["Castling"] = "KQkq",
		["Mover"] = "w",
		["FullMoves"] = 0,
		["HalfMoves"] = 0,
		["GameEnded"] = false,
		["Ending"] = "Resignation",
		["Winner"] = "w",
		["FENMoves"] = {},
		["EnPassant"] = nil
	}
	
	function self.ToFEN(self, ExcludeInfo)
		local BoardString = ""
		
		-- loop over rows
		for y=1, 8 do
			local Empty = 0 
			
			-- loop columns
			for x = 1, 8 do
				local Piece = self.Board[y][x]
				
				if Piece == " " then
					Empty = Empty + 1
				else
					-- Add the amount of empty squares or the piece
					if Empty > 0 then
						BoardString = BoardString .. Empty
						Empty = 0
					end
					BoardString = BoardString .. Piece
				end
			end
			
			-- if the row does not end with a piece 
			if Empty > 0 then
				BoardString = BoardString .. Empty
			end
			
			-- add some divider thing for the FEN to work
			if y ~= 8 then
				BoardString = BoardString .. "/"
			end
		end
		
		if not ExcludeInfo then
			-- add the extra info at the end
			BoardString ..= ` {self.Mover} {self.Castling} - {tostring(self.HalfMoves)} {tostring(self.FullMoves)}`
		end
		
		return BoardString
	end
	
	function self.GetPieceOnPos(self, Pos: Vector2)
		return self.Board[Pos.Y][Pos.X]
	end
	
	function self.LoadFEN(self, FEN)
		local Info = string.split(FEN, " ")
		
		for Y, Row in string.split(Info[1], "/") do
			local X = 1
			-- X is for the Board
			-- iX is for the string thing
			
			for iX=1, #Row do
				local Piece = string.sub(Row, iX, iX)
				
				if tonumber(Piece) then
					for i=1, tonumber(Piece) do
						self.Board[Y][X] = " "
						X += 1
						-- the square is empty because its a number, then add an offset to X
					end
				else
					self.Board[Y][X] = Piece
					X += 1
				end
			end
		end
		
		-- load the other info
		self.Castling = Info[3]
		self.Mover = Info[2]
		self.HalfMoves = tonumber(Info[5])
		self.FullMoves = tonumber(Info[6])
	end
	
	function self.CanBeTaken(self, Team, Pos)
		local OriginalPiece = self.Board[Pos.Y][Pos.X]
		-- save the piece on the pos because it will be replaced 
		
		self.Board[Pos.Y][Pos.X] = Team == "W" and "P" or "p"
		-- create a dummy piece and check if it can be taken with self:GetLegalPos

		for y, Row in self.Board do
			for x, Piece in Row do
				if Piece == " " or GetTeam(Piece) == Team then 
					continue
				end

				local Positions = self:GetLegalPos(Vector2.new(x, y), true)

				if table.find(Positions, Pos) then
					self.Board[Pos.Y][Pos.X] = OriginalPiece
					return Positions
				end
			end
		end

		self.Board[Pos.Y][Pos.X] = OriginalPiece
		return false
	end
	
	function self.GetLegalPos(self, PiecePos, AvoidThreats)
		local Piece = self:GetPieceOnPos(PiecePos)
		local LegalPos = {}
		
		if Piece == "P" then
			-- white pawn
			
			-- checking if there is an enemy on the left side
			if PiecePos.X - 1 > 0 and PiecePos.Y - 1 > 0 then
				local NeighborRight = self:GetPieceOnPos(Vector2.new(PiecePos.X - 1, PiecePos.Y - 1))

				if NeighborRight ~= " " and GetTeam(NeighborRight) ~= GetTeam(Piece) then
					table.insert(LegalPos, Vector2.new(PiecePos.X - 1, PiecePos.Y - 1))
				end
			end
			
			-- checking if there is an enemy on the right side
			if PiecePos.X + 1 <= 8 and PiecePos.Y - 1 > 0 then
				local NeighborLeft = self:GetPieceOnPos(Vector2.new(PiecePos.X + 1, PiecePos.Y - 1))

				if NeighborLeft ~= " " and GetTeam(NeighborLeft) ~= GetTeam(Piece) then
					table.insert(LegalPos, Vector2.new(PiecePos.X + 1, PiecePos.Y - 1))
				end
			end
			
			-- checks if it can move forward
			if PiecePos.Y - 1 > 0 and self:GetPieceOnPos(Vector2.new(PiecePos.X, PiecePos.Y - 1)) == " " then
				table.insert(LegalPos, Vector2.new(PiecePos.X, PiecePos.Y - 1))
				
				-- checks if it can move 2 squares forward
				if PiecePos.Y == 7 and self:GetPieceOnPos(Vector2.new(PiecePos.X, PiecePos.Y - 2)) == " " then
					table.insert(LegalPos, Vector2.new(PiecePos.X, PiecePos.Y - 2))
				end
			end
			
			-- checking if en passant is available
			if self.EnPassant and (PiecePos.Y == self.EnPassant.Y) then
				if (PiecePos.X + 1 == self.EnPassant.X or PiecePos.X - 1 == self.EnPassant.X) then
					local NewPosition = Vector2.new(PiecePos.X + 1 == self.EnPassant.X and PiecePos.X + 1 or PiecePos.X - 1, PiecePos.Y - 1)
					local PieceOnNewPos = self:GetPieceOnPos(NewPosition)
					
					if PieceOnNewPos == " " then
						table.insert(LegalPos, NewPosition) 
					end
				end
			end
		elseif Piece == "p" then
			-- black pawn
			
			-- checking if there is an enemy on the right side
			if PiecePos.X - 1 > 0 and PiecePos.Y + 1 <= 8 then
				local NeighborRight = self:GetPieceOnPos(Vector2.new(PiecePos.X - 1, PiecePos.Y + 1))

				if NeighborRight ~= " " and GetTeam(NeighborRight) ~= GetTeam(Piece) then
					table.insert(LegalPos, Vector2.new(PiecePos.X - 1, PiecePos.Y + 1))
				end
			end
			
			-- checking if there is an enemy on the left side
			if PiecePos.X + 1 <= 8 and PiecePos.Y + 1 <= 8 then
				local NeighborLeft = self:GetPieceOnPos(Vector2.new(PiecePos.X + 1, PiecePos.Y + 1))

				if NeighborLeft ~= " " and GetTeam(NeighborLeft) ~= GetTeam(Piece) then
					table.insert(LegalPos, Vector2.new(PiecePos.X + 1, PiecePos.Y + 1))
				end
			end
			
			-- checks if it can move forward
			if PiecePos.Y + 1 <= 8 and self:GetPieceOnPos(Vector2.new(PiecePos.X, PiecePos.Y + 1)) == " " then
				table.insert(LegalPos, Vector2.new(PiecePos.X, PiecePos.Y + 1))
				
				-- checks if it can move 2 squares forward
				if PiecePos.Y == 2 and self:GetPieceOnPos(Vector2.new(PiecePos.X, PiecePos.Y + 2)) == " " then
					table.insert(LegalPos, Vector2.new(PiecePos.X, PiecePos.Y + 2))
				end
			end
			
			-- checks for en passant
			if self.EnPassant and (PiecePos.Y == self.EnPassant.Y) then
				if (PiecePos.X + 1 == self.EnPassant.X or PiecePos.X - 1 == self.EnPassant.X) then
					local NewPosition = Vector2.new(PiecePos.X + 1 == self.EnPassant.X and PiecePos.X + 1 or PiecePos.X - 1, PiecePos.Y + 1)
					local PieceOnNewPos = self:GetPieceOnPos(NewPosition)
					
					if PieceOnNewPos == " " then
						table.insert(LegalPos, NewPosition) 
					end
				end
			end
		elseif string.lower(Piece) == "n" then
			-- knight
			
			local KnightPositions = {
				Vector2.new(PiecePos.X - 1, PiecePos.Y - 2), -- bottom left
				Vector2.new(PiecePos.X + 1, PiecePos.Y - 2), -- upper left
				Vector2.new(PiecePos.X - 1, PiecePos.Y + 2), -- top left
				Vector2.new(PiecePos.X + 1, PiecePos.Y + 2), -- top right
				Vector2.new(PiecePos.X + 2, PiecePos.Y + 1), -- upper right
				Vector2.new(PiecePos.X + 2, PiecePos.Y - 1), -- lower right
				Vector2.new(PiecePos.X - 2, PiecePos.Y + 1), -- upper left
				Vector2.new(PiecePos.X - 2, PiecePos.Y - 1), -- lower left
			}

			for i, KnightPosition in KnightPositions do
				-- if the knight position is over the board
				if KnightPosition.X > 8 or KnightPosition.Y > 8 or KnightPosition.X < 1 or KnightPosition.Y < 1 then
					continue
				end

				local PieceOnPosition = self:GetPieceOnPos(KnightPosition)
				
				-- if the square is empty or the square has an enemy piece
				if PieceOnPosition == " " or GetTeam(PieceOnPosition) ~= GetTeam(Piece) then
					table.insert(LegalPos, KnightPosition)
				end
			end
		elseif string.lower(Piece) == "k" then
			-- king
			
			local KingPositions = {
				Vector2.new(PiecePos.X - 1, PiecePos.Y + 1), -- upper left
				Vector2.new(PiecePos.X, PiecePos.Y + 1), -- up
				Vector2.new(PiecePos.X + 1, PiecePos.Y + 1), --upper right
				Vector2.new(PiecePos.X - 1, PiecePos.Y - 1), --lower left
				Vector2.new(PiecePos.X, PiecePos.Y - 1), -- bottom
				Vector2.new(PiecePos.X + 1, PiecePos.Y - 1), -- bottom right
				Vector2.new(PiecePos.X + 1, PiecePos.Y), -- right
				Vector2.new(PiecePos.X - 1, PiecePos.Y), -- left
			}
			
			-- if the king is white
			if GetTeam(Piece) == "W" then
				-- checks if it can castle on the king side
				if ({string.find(self.Castling, "K")})[1] then
					local CanSwitch = true
					
					-- checks if nothing is blocking
					for i=6, 7 do
						if self:GetPieceOnPos(Vector2.new(i, 8)) == " " then
							continue
						end

						CanSwitch = false
						break
					end
					
					-- checks if castling is safe
					if (CanSwitch and AvoidThreats) or (not AvoidThreats and CanSwitch and (not self:CanBeTaken("W", Vector2.new(7, 8)) and not self:CanBeTaken("W", PiecePos))) then
						table.insert(LegalPos, Vector2.new(7, 8))
						table.insert(LegalPos, Vector2.new(8, 8))
					end
				end
				
				-- castling for the queen side
				if ({string.find(self.Castling, "Q")})[1] then
					local CanSwitch = true
					
					--checks if nothing is blocking
					for i=4, 2, -1 do
						if self:GetPieceOnPos(Vector2.new(i, 8)) == " " then
							continue
						end

						CanSwitch = false
						break
					end
					
					-- checks if castling is safe
					if (CanSwitch and AvoidThreats) or (not AvoidThreats and CanSwitch and (not self:CanBeTaken("W", Vector2.new(3, 8)) and not self:CanBeTaken("W", PiecePos))) then
						table.insert(LegalPos, Vector2.new(3, 8))
						table.insert(LegalPos, Vector2.new(1, 8))
					end
				end
			else
				-- king for black
				
				-- checks if it can castle on the king side
				if ({string.find(self.Castling, "k")})[1] then
					local CanSwitch = true
					
					-- checks if nothing is blocking
					for i=6, 7 do
						if self:GetPieceOnPos(Vector2.new(i, 1)) == " " then
							continue
						end

						CanSwitch = false
						break
					end
					
					-- checks if castling is safe
					if (CanSwitch and AvoidThreats) or (not AvoidThreats and CanSwitch and (not self:CanBeTaken("B", Vector2.new(7, 1)) and not self:CanBeTaken("B", PiecePos))) then
						table.insert(LegalPos, Vector2.new(7, 1))
						table.insert(LegalPos, Vector2.new(8, 1))
					end
				end
				
				-- castling for the queen side
				if ({string.find(self.Castling, "q")})[1] then
					local CanSwitch = true
					
					-- checks if nothing is blocking
					for i=4, 2, -1 do
						if self:GetPieceOnPos(Vector2.new(i, 1)) == " " then
							continue
						end

						CanSwitch = false
						break
					end
					
					-- checks if castling is safe
					if (CanSwitch and AvoidThreats) or (not AvoidThreats and CanSwitch and (not self:CanBeTaken("B", Vector2.new(3, 1)) and not self:CanBeTaken("B", PiecePos))) then
						table.insert(LegalPos, Vector2.new(3, 1))
						table.insert(LegalPos, Vector2.new(1, 1))
					end
				end
			end
			
			-- checks if the available positions are safe
			for i, KingPosition in KingPositions do
				if KingPosition.X > 8 or KingPosition.Y > 8 or KingPosition.X < 1 or KingPosition.Y < 1 then
					continue
				end

				local PieceOnPosition = self:GetPieceOnPos(KingPosition)
				
				if (PieceOnPosition == " " or GetTeam(PieceOnPosition) ~= GetTeam(Piece)) then
					if not AvoidThreats and not self:CanBeTaken(GetTeam(Piece), KingPosition) then
						table.insert(LegalPos, KingPosition)
					elseif AvoidThreats then
						table.insert(LegalPos, KingPosition)
					end
				end
			end
		elseif string.lower(Piece) == "r" or string.lower(Piece) == "q" then
			-- rook or the queen
			
			-- moves to the right
			for i=1, 8 - PiecePos.X do
				local PieceOnPosition = self:GetPieceOnPos(Vector2.new(PiecePos.X + i, PiecePos.Y))

				if PieceOnPosition == " " or GetTeam(PieceOnPosition) ~= GetTeam(Piece) then
					table.insert(LegalPos, Vector2.new(PiecePos.X + i, PiecePos.Y))
				end

				if PieceOnPosition ~= " " then
					break
				end
			end
			
			-- moves to the left
			for i=1, PiecePos.X - 1 do
				local PieceOnPosition = self:GetPieceOnPos(Vector2.new(PiecePos.X - i, PiecePos.Y))

				if PieceOnPosition == " " or GetTeam(PieceOnPosition) ~= GetTeam(Piece) then
					table.insert(LegalPos, Vector2.new(PiecePos.X - i, PiecePos.Y))
				end

				if PieceOnPosition ~= " " then
					break
				end
			end
			
			-- moves up
			for i=1, 8 - PiecePos.Y do
				local PieceOnPosition = self:GetPieceOnPos(Vector2.new(PiecePos.X, PiecePos.Y + i))

				if PieceOnPosition == " " or GetTeam(PieceOnPosition) ~= GetTeam(Piece) then
					table.insert(LegalPos, Vector2.new(PiecePos.X, PiecePos.Y + i))
				end

				if PieceOnPosition ~= " " then
					break
				end
			end
			
			--moves down
			for i=1, PiecePos.Y - 1 do
				local PieceOnPosition = self:GetPieceOnPos(Vector2.new(PiecePos.X, PiecePos.Y - i))

				if PieceOnPosition == " " or GetTeam(PieceOnPosition) ~= GetTeam(Piece) then
					table.insert(LegalPos, Vector2.new(PiecePos.X, PiecePos.Y - i))
				end

				if PieceOnPosition ~= " " then
					break
				end
			end
		end
		
		if string.lower(Piece) == "b" or string.lower(Piece) == "q" then
			-- bishop or queen
			
			-- upper right
			for i=1, 8 do
				if PiecePos.X + i > 8 or PiecePos.Y + i > 8 then break end
				
				local PieceOnPosition = self:GetPieceOnPos(Vector2.new(PiecePos.X + i, PiecePos.Y + i))

				if PieceOnPosition == " " or GetTeam(PieceOnPosition) ~= GetTeam(Piece) then
					table.insert(LegalPos, Vector2.new(PiecePos.X + i, PiecePos.Y + i))
				end

				if PieceOnPosition ~= " " then
					break
				end
			end
			
			-- lower left
			for i=1, 8 do
				if PiecePos.X - i < 1 or PiecePos.Y - i < 1 then break end

				local PieceOnPosition = self:GetPieceOnPos(Vector2.new(PiecePos.X - i, PiecePos.Y - i))

				if PieceOnPosition == " " or GetTeam(PieceOnPosition) ~= GetTeam(Piece) then
					table.insert(LegalPos, Vector2.new(PiecePos.X - i, PiecePos.Y - i))
				end

				if PieceOnPosition ~= " " then
					break
				end
			end
			
			-- lower right
			for i=1, 8 do
				if PiecePos.X + i > 8 or PiecePos.Y - i < 1 then break end

				local PieceOnPosition = self:GetPieceOnPos(Vector2.new(PiecePos.X + i, PiecePos.Y - i))

				if PieceOnPosition == " " or GetTeam(PieceOnPosition) ~= GetTeam(Piece) then
					table.insert(LegalPos, Vector2.new(PiecePos.X + i, PiecePos.Y - i))
				end

				if PieceOnPosition ~= " " then
					break
				end
			end
			
			-- upper left
			for i=1, 8 do
				if PiecePos.X - i < 1 or PiecePos.Y + i  > 8 then break end

				local PieceOnPosition = self:GetPieceOnPos(Vector2.new(PiecePos.X - i, PiecePos.Y + i))

				if PieceOnPosition == " " or GetTeam(PieceOnPosition) ~= GetTeam(Piece) then
					table.insert(LegalPos, Vector2.new(PiecePos.X - i, PiecePos.Y + i))
				end

				if PieceOnPosition ~= " " then
					break
				end
			end
		end
		
		-- checks if the king can be taken on the positions
		if not AvoidThreats then
			local OriginalFENGame = self:ToFEN()
			-- save the FEN because we will change the board to do this
			local HasInvalid = false
			
			for i, LegalPosition in LegalPos do
				self:Move(PiecePos, LegalPosition, {["AvoidThreats"] = true})
				-- Move with AvoidThreats enabled so it wonr error "executed past deadline" thing
				
				-- get the king for the team
				local KingPosition = nil

				for y, Row in self.Board do
					for x, PieceBoard in Row do
						if PieceBoard == (GetTeam(Piece) == "W" and "K" or "k") then
							KingPosition = Vector2.new(x, y)
							break
						end
					end
				end
				
				-- if the king can be taken on that position
				if self:CanBeTaken(GetTeam(Piece), KingPosition) then
					LegalPos[i] = 0
					HasInvalid = true
				end
				
				-- set the FEN back to the original
				self:LoadFEN(OriginalFENGame)
			end
			
			-- remove the positions unavailable here because i cant change it on the for loop above
			repeat 
				HasInvalid = false
				for i, LegalPosition in LegalPos do
					if LegalPosition == 0 then
						table.remove(LegalPos, i)
						HasInvalid = true
						break
					end
				end
			until not HasInvalid 
		end
		
		return LegalPos
	end
	
	function self.IsCheck(self, Team)
		-- checks if the king is in threat of being taken
		
		local KingPosition = nil
		
		for y, Row in self.Board do
			for x, Piece in Row do
				if Piece == (Team == "w" and "K" or "k") then
					KingPosition = Vector2.new(x, y)
					break
				end
			end
		end
		
		return self:CanBeTaken(Team == "w" and "W" or "B", KingPosition)
	end

	function self.IsStalemate(self, SideMove)
		-- checks if the king does not have anywhere to go and it is not in check
		
		for y, Row in self.Board do
			for x, Piece in Row do
				if GetTeam(Piece) ~= (SideMove == "w" and "W" or "B") then 
					continue
				end
				
				if #self:GetLegalPos(Vector2.new(x, y)) > 0 then
					return false
				end
			end
		end
		return true 
	end
	
	function self.GetPieces(self)
		-- gets the pieces on a table
		
		local Pieces = {}
		
		for y, Row in self.Board do
			for x, Piece in Row do
				if Piece == " " then
					continue
				end
				
				table.insert(Pieces, {Piece, Vector2.new(x, y)})
			end
		end
		
		return Pieces 
	end
	
	function self.InsufficientMating(self)
		-- when a checkmate is not possible no matter how many moves you make
		-- and the pawns cant move
		
		local Pieces = self:GetPieces()
		
		-- cant checkmate with only a bishop or a knight
		local Insufficient = {"b", "n", "bB", "N", "B", "", "Bb"}
		local PawnCanMove = false
		local PieceString = ""
		
		-- make the piece string without the king
		for i, Info in Pieces do
			local Piece, Position = table.unpack(Info)
			
			if string.lower(Piece) == "k" then
				continue
			end
			
			if string.lower(Piece) == "p" and not PawnCanMove then
				local Moves = self:GetLegalPos(Position)
				
				if #Moves > 0 then
					PawnCanMove = true
				end
			end
			
			if string.lower(Piece) ~= "p" then
				PieceString ..= Piece
			end
		end
		
		-- if the pawn cant move or PieceString is in Insufficient
		return (not PawnCanMove) and (not not table.find(Insufficient, PieceString))
	end

	function self.Move(self, StartPos: Vector2, NewPos: Vector2, SpecialParameters)
		--AvoidThreats is to avoid infinite looping when checking the Legal positions
		local AvoidThreats = SpecialParameters["AvoidThreats"]
		
		local LegalMoves = self:GetLegalPos(StartPos, AvoidThreats)
		local PieceOnPos = self:GetPieceOnPos(StartPos)
		local SideMove = GetTeam(PieceOnPos)
		local PieceOnNewPos = self:GetPieceOnPos(NewPos)
		
		-- the position is not legal
		if not table.find(LegalMoves, NewPos) then
			return 
		end
		
		-- play sound if the special parameters have it
		local function PlaySound(Sound)
			if SpecialParameters["Sound"] and SpecialParameters["Sound"][Sound] then
				SpecialParameters["Sound"][Sound]()
			end
		end
		
		if not AvoidThreats then
			PlaySound("Move")
		end
		
		-- add half moves
		if PieceOnNewPos ~= " " then
			self.HalfMoves = 0
		end
		
		-- adds FullMoves by 1 if it is white's turn
		if SideMove == "W" then
			self.FullMoves += 1
		end
		
		-- if castling on the other team is available and we snatch it from happening
		if PieceOnNewPos ~= " " and GetTeam(PieceOnNewPos) ~= SideMove and string.lower(PieceOnNewPos) == "r" and not AvoidThreats then
			if NewPos.X == 1 then
				self.Castling = string.gsub(self.Castling, SideMove == "W" and "q" or "Q", "")
			elseif NewPos.X == 8  then
				self.Castling = string.gsub(self.Castling, SideMove == "W" and "k" or "K", "")
			end 
			if self.Castling == "" then self.Castling = "-" end
		end
		
		-- when castling is available and we move the rook
		if string.lower(PieceOnPos) == "r" and not AvoidThreats then
			if StartPos.X == 1 then
				self.Castling = string.gsub(self.Castling, SideMove == "W" and "Q" or "q", "")
			elseif StartPos.X == 8  then
				self.Castling = string.gsub(self.Castling, SideMove == "W" and "K" or "k", "")
			end
			if self.Castling == "" then self.Castling = "-" end
		end
		
		-- the en passant special move opportunity only lasts a single move
		if not AvoidThreats then
			self.EnPassant = nil
			self.Mover = SideMove == "W" and "b" or "w"
		end
		
		-- add HalfMoves
		self.HalfMoves += 1
		
		-- moving the pieces for castling
		if string.lower(PieceOnPos) == "k" then
			self.Castling = ({string.gsub(self.Castling, SideMove == "W" and "%u" or "%l", "")})[1]
			if self.Castling == "" then self.Castling = "-" end
			
			-- queen side castle
			if NewPos.X > StartPos.X + 1 then
				self.Board[StartPos.Y][8] = " "
				self.Board[StartPos.Y][StartPos.X] = " "
				self.Board[NewPos.Y][6] = GetTeam(PieceOnPos) == "W" and "R" or "r"
				self.Board[NewPos.Y][7] = GetTeam(PieceOnPos) == "W" and "K" or "k"
				
				if not AvoidThreats then
					table.insert(self.FENMoves, self:ToFEN(true))
					PlaySound("Castle")
				end
				
				return
			elseif NewPos.X < StartPos.X - 1 then
				-- king side castle
				
				self.Board[StartPos.Y][1] = " "
				self.Board[StartPos.Y][StartPos.X] = " "
				self.Board[NewPos.Y][4] = GetTeam(PieceOnPos) == "W" and "R" or "r"
				self.Board[NewPos.Y][3] = GetTeam(PieceOnPos) == "W" and "K" or "k"
				
				if not AvoidThreats then
					table.insert(self.FENMoves, self:ToFEN(true))
					PlaySound("Castle")
				end
				
				return
			end
		end	
		
		self.Board[StartPos.Y][StartPos.X] = " "
		-- removes the piece on start pos
		
		if self.Board[NewPos.Y][NewPos.X] ~= " " and GetTeam(self.Board[NewPos.Y][NewPos.X]) ~= SideMove and not AvoidThreats then
			PlaySound("Take")
		end
		
		if string.lower(PieceOnPos) == "p" then
			self.HalfMoves = 0
			
			-- promotion, automatically set it to the queen because absolutely no one chooses the others... except the knight
			if NewPos.Y == (SideMove == "W" and 1 or 8) then
				self.Board[NewPos.Y][NewPos.X] = SideMove == 'W' and "Q" or "q"

				PlaySound("Promotion")

				if not AvoidThreats then
					table.insert(self.FENMoves, self:ToFEN(true))
				end
				return
			end
			
			-- en passant 
			if NewPos.X ~= StartPos.X and PieceOnNewPos == " " and (GetTeam(self:GetPieceOnPos(Vector2.new(NewPos.X, StartPos.Y)))) then
				self.Board[StartPos.Y][NewPos.X] = " "
			end
			
			-- it moves 2 squares, and there is a piece there, en passant 
			if NewPos.Y == (SideMove == "W" and 5 or 4) and StartPos.Y == (SideMove == "W" and 7 or 2) and not AvoidThreats then
				self.EnPassant = NewPos
			end
		end
		
		-- set the piece on the new position
		self.Board[NewPos.Y][NewPos.X] = PieceOnPos
		
		if not AvoidThreats then
			table.insert(self.FENMoves, self:ToFEN(true))
			
			if self:IsCheck(self.Mover) then
				PlaySound("Check")
			end
			
			-- if the other team is in check and it cant move anything, its a checkmate
			-- if the other team cant move and it it not in check, it is a stalemate
			-- if no pieces are taken or no pawns are moved for 50 moves, its a draw by the 50 move rule
			-- if the game has been in the position 3 times, its a draw by repetition
			-- if the team does not have enough material to checkmate, it is a draw by insuficient material
			
			if self:IsCheck(self.Mover) and self:IsStalemate(self.Mover) then
				self.Winner = self.Mover == "w" and "b" or "w"
				self.Ending = "Checkmate"
				self.GameEnded = true
				PlaySound("Checkmate")
			elseif self:IsStalemate(self.Mover) then
				self.Ending = "Stalemate"
				self.GameEnded = true
				PlaySound("End")
			elseif self.HalfMoves >= 50 then
				self.Ending = "50 move rule"
				self.GameEnded = true
				PlaySound("End")
			elseif #FindInTable(self.FENMoves, self:ToFEN(true)) >= 3 then
				self.Ending = "Repetition"
				self.GameEnded = true
				PlaySound("End")
			elseif self:InsufficientMating(self.Mover) then
				self.Ending = "Insufficient material"
				self.GameEnded = true
				PlaySound("End")
			end
		end
	end

	return setmetatable(self, Main)
end

--TODO: select pawn promotion

return Main
