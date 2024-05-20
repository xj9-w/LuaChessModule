local TweenService = game:GetService("TweenService")

local Main = script.Parent
local Modules = Main:WaitForChild("Modules")
local Templates = Main:WaitForChild("Templates")
local ChessUI = Main:WaitForChild("Main")
local EndedUI = ChessUI:WaitForChild("GameEnded")
local Content = ChessUI:WaitForChild("Content")
local Board = Content:WaitForChild("Board")
local Hints = Board:WaitForChild("Hints")
local Pieces = Board:WaitForChild("Pieces")
local Highlight = Board:WaitForChild("Highlight")

local ChessMain = require(Modules:WaitForChild("MainChess"))
local Engine = require(Modules:WaitForChild("Engine"))
local SoundModule = require(Modules:WaitForChild("Sounds"))

SoundModule.SoundLocation = ChessUI.MainSound
ChessUI.Visible = true

local function NotationToVector(Notation)
	return Vector2.new(
		({string.find("abcdefgh", string.sub(Notation, 1, 1))})[1],
		9 - tonumber(string.sub(Notation, 2, 2))
	), Vector2.new(
		({string.find("abcdefgh", string.sub(Notation, 3, 3))})[1],
		9 - tonumber(string.sub(Notation, 4, 4))
	)
end

local function VectorToName(Vector)
	return tostring(Vector.X) .. " " .. tostring(Vector.Y)
end

local function NameToVector(Vector)
	return Vector2.new(table.unpack(string.split(Vector, " ")))
end

local ChessGame = nil

local Player = nil
local FENGame = nil

local MovePicked = nil
local SelectedPiece = nil
local CanSelectPiece = nil

local HintsClicked = {}

local function LoadChessPieces()
	local PieceRectSize = {
		["K"] = Vector2.new(),
		["Q"] = Vector2.new(133),
		["B"] = Vector2.new(266),
		["N"] = Vector2.new(399),
		["R"] = Vector2.new(532),
		["P"] = Vector2.new(665),
		["k"] = Vector2.new(0, 133),
		["q"] = Vector2.new(133, 133),
		["b"] = Vector2.new(266, 133),
		["n"] = Vector2.new(399, 133),
		["r"] = Vector2.new(532, 133),
		["p"] = Vector2.new(665, 133)
	}
	
	Pieces:ClearAllChildren()
	
	for y, Row in ChessGame.Board do
		for x, Piece in Row do
			if Piece == " " then continue end
			
			local PieceObj = Templates.Piece:Clone()
			PieceObj.Position = UDim2.fromScale(0.125 * (x - 1), 0.125 * (y - 1))
			PieceObj.Name = VectorToName(Vector2.new(x, y))
			PieceObj.ImageRectSize = Vector2.new(133, 133)
			PieceObj.ImageRectOffset = PieceRectSize[Piece]
			
			local PieceTeam = string.upper(Piece) == Piece and "w" or "b"

			PieceObj.MouseButton1Down:Connect(function()
				if Player ~= PieceTeam then
					return
				end

				Hints:ClearAllChildren()
				if SelectedPiece == PieceObj or not CanSelectPiece then
					SelectedPiece = nil
					return Hints:ClearAllChildren()
				end
				SelectedPiece = PieceObj

				local LegalMoves = ChessGame:GetLegalPos(Vector2.new(x, y))

				for i, LegalMove in LegalMoves do
					local PieceOnPos = ChessGame.Board[LegalMove.Y][LegalMove.X]
					local Hint = (PieceOnPos ~= " " and Templates.CaptureHint or Templates.Hint):Clone()
					Hint.Position = UDim2.fromScale(0.125 * (LegalMove.X - 1), 0.125 * (LegalMove.Y - 1))
					
					HintsClicked[VectorToName(Vector2.new(x, y))] = function()
						MovePicked = {
							Vector2.new(x, y),
							LegalMove
						}
					end
			
					Hint.MouseButton1Click:Connect(HintsClicked[VectorToName(Vector2.new(x, y))])
					Hint.Parent = Hints
				end
			end)

			PieceObj.Parent = Pieces
		end
	end
end


local function CreateHighlight(Pos)
	local NewHighlight = Templates.HoverSquare:Clone()
	NewHighlight.Position = UDim2.fromScale(0.125 * (Pos.X - 1), 0.125 * (Pos.Y - 1))
	NewHighlight.Parent = Highlight
end

ChessUI.Settings.MouseButton1Click:Connect(function()
	ChessUI.Options.Visible = not ChessUI.Options.Visible
end)

ChessUI.Options.Resign.MouseButton1Click:Connect(function()
	if ChessGame.GameEnded then return end
	
	ChessGame.GameEnded = true
	SoundModule["End"]()
end)

while true do
	ChessGame = ChessMain.NewGame()

	Player = "w"
	FENGame = ChessGame:ToFEN()

	MovePicked = nil
	SelectedPiece = nil
	CanSelectPiece = true
	
	LoadChessPieces()
	
	Hints:ClearAllChildren()
	Highlight:ClearAllChildren()

	while not ChessGame.GameEnded do
		Hints:ClearAllChildren()
		
		SelectedPiece = nil
		MovePicked = nil

		CanSelectPiece = ChessGame.Mover == Player
		
		if ChessGame.Mover ~= Player then
			task.spawn(function()
				MovePicked = {NotationToVector(Engine(FENGame))}
			end)
		end
		
		repeat task.wait() until MovePicked or ChessGame.GameEnded

		if MovePicked then
			StartPos, NewPos = table.unpack(MovePicked)
			
			Highlight:ClearAllChildren()
			CreateHighlight(StartPos)
			CreateHighlight(NewPos)
			
			local PlayingTweens = 0

			ChessGame:Move(StartPos, NewPos, {
				["Sound"] = SoundModule
			})
			
			local Tween = TweenService:Create(
				Pieces[VectorToName(StartPos)],
				TweenInfo.new(0.1),
				{["Position"] = UDim2.fromScale(0.125 * (NewPos.X - 1), 0.125 * (NewPos.Y - 1))}
			)

			Tween:Play()
			Tween.Completed:Wait()
			
			if Pieces:FindFirstChild(VectorToName(NewPos)) then
				Pieces[VectorToName(NewPos)]:Destroy()
			end
			task.wait() -- this is required
			
			LoadChessPieces()
			
			SelectedPiece = nil
			FENGame = ChessGame:ToFEN()
			CanSelectPiece = false
		end
	end
	
	local Ending = ChessGame.Ending
	local Winner = ChessGame.Winner
	
	EndedUI.Ending.Text = Ending == "Checkmate" and (Winner == string.lower(Player) and "You Won!" or "You Lost") or (Ending == "Resignation" and "You Lost" or "Draw")
	EndedUI.EndingInfo.Text = `Game ended by {string.lower(Ending)}`
	
	EndedUI.Visible = true
	
	EndedUI.Reset.MouseButton1Click:Wait()
	EndedUI.Visible = false
end
