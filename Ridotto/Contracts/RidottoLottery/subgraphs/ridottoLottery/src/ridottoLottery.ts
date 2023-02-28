/* eslint-disable prefer-const */
import { BigDecimal, BigInt, Bytes, log } from "@graphprotocol/graph-ts";
import { concat } from "@graphprotocol/graph-ts/helper-functions";
import { Lottery, Round, User } from "../generated/schema";
import {
  LotteryClose,
  LotteryNumberDrawn,
  LotteryOpen,
  TicketsClaim,
  TicketsPurchase,
  ridottoLottery,
} from "../generated/ridottoLottery/ridottoLottery";
import { toBigDecimal } from "./utils";

// BigNumber-like references
let ZERO_BI = BigInt.fromI32(0);
let ONE_BI = BigInt.fromI32(1);
let ZERO_BD = BigDecimal.fromString("0");

export function handleLotteryOpen(event: LotteryOpen): void {
  let lottery = new Lottery(event.params.lotteryId.toString());
  let contract = ridottoLottery.bind(event.address);
  lottery.totalUsers = ZERO_BI;
  lottery.totalTickets = ZERO_BI;
  lottery.status = "Open";
  lottery.startTime = event.params.startTime.toI32();
  lottery.endTime = event.params.endTime.toI32();
  lottery.ticketPrice = toBigDecimal(event.params.priceTicketInToken);
  lottery.firstTicket = event.params.firstTicketId;
  lottery.block = event.block.number;
  lottery.timestamp = event.block.timestamp.toI32();
  let x = contract.viewLottery(event.params.lotteryId).rewardsBreakdown;
  lottery.RewardDistribution = x;
  lottery.save();
}

export function handleLotteryClose(event: LotteryClose): void {
  let lottery = Lottery.load(event.params.lotteryId.toString());
  let contract = ridottoLottery.bind(event.address);
  if (lottery !== null) {
    lottery.status = "Close";
    lottery.lastTicket = event.params.firstTicketIdNextLottery;
    lottery.totalAccumalated = contract.viewLottery(
      event.params.lotteryId
    ).amountCollectedInLotteryToken;
    lottery.save();
  }
}

export function handleLotteryNumberDrawn(event: LotteryNumberDrawn): void {
  let lottery = Lottery.load(event.params.lotteryId.toString());
  let contract = ridottoLottery.bind(event.address);
  if (lottery !== null) {
    lottery.status = "Claimable";
    lottery.finalNumber = event.params.finalNumber.toI32();
    lottery.winningTickets = event.params.countWinningTickets.toI32();
    lottery.claimedTickets = ZERO_BI;
    let x: BigInt[] = [];

    for (
      let index = 0;
      index <
      contract.viewLottery(event.params.lotteryId).countWinnersPerBracket
        .length;
      index++
    ) {
      const element = contract.viewLottery(event.params.lotteryId)
        .countWinnersPerBracket[index];

      x.push(element as BigInt);
    }

    lottery.BracketWinnerCount = x;
    lottery.save();
  }
}

export function handleTicketsPurchase(event: TicketsPurchase): void {
  let lottery = Lottery.load(event.params.lotteryId.toString());
  let contract = ridottoLottery.bind(event.address);
  if (lottery === null) {
    log.warning("Trying to purchase tickets for an unknown lottery - #{}", [
      event.params.lotteryId.toString(),
    ]);
    lottery = new Lottery(event.params.lotteryId.toHexString());
  }
  lottery.totalTickets = lottery.totalTickets.plus(event.params.numberTickets);
  lottery.save();

  let user = User.load(event.params.buyer.toHex());
  if (user === null) {
    user = new User(event.params.buyer.toHex());
    user.totalRounds = ZERO_BI;
    user.totalTickets = ZERO_BI;
    user.totalLotteryToken = ZERO_BD;
    user.block = event.block.number;
    user.timestamp = event.block.timestamp.toI32();
    user.save();
  }
  let t = 0;
  let i = 0;
  for (i = 0; i < event.params.ticketNumbers.length; i++) {
    if (event.params.ticketNumbers[i] != BigInt.zero()) {
      t++;
    }
  }
  user.totalTickets = user.totalTickets.plus(BigInt.fromI32(t));
  user.totalLotteryToken = user.totalLotteryToken.plus(
    event.params.numberTickets.toBigDecimal().times(lottery.ticketPrice)
  );
  user.save();

  let roundId = concat(
    Bytes.fromHexString(event.params.buyer.toHex()),
    Bytes.fromUTF8(event.params.lotteryId.toString())
  ).toHex();
  let round = Round.load(roundId);
  if (round === null) {
    round = new Round(roundId);
    round.lottery = event.params.lotteryId.toString();
    round.user = event.params.buyer.toHex();
    round.totalTickets = ZERO_BI;
    round.block = event.block.number;
    round.timestamp = event.block.timestamp.toI32();
    round.TicketIds = [];
    round.TicketNumbers = [];
    round.save();

    user.totalRounds = user.totalRounds.plus(BigInt.fromI32(1));
    user.save();

    lottery.totalUsers = lottery.totalUsers.plus(ONE_BI);
    lottery.save();
  }
  round.totalTickets = round.totalTickets.plus(BigInt.fromI32(1));

  let x: BigInt[] = round.TicketNumbers as BigInt[];
  let y = contract.currentTicketId().minus(event.params.numberTickets).toI32();
  let z = round.TicketIds as i32[];

  for (let index = 0; index < event.params.ticketNumbers.length; index++) {
    const element = event.params.ticketNumbers[index];
    if (element.toI32() != 0) {
      x.push(element as BigInt);
      z.push(y + index);
    }
  }
  round.TicketNumbers = x;
  round.TicketIds = z;
  round.save();
}

export function handleTicketsClaim(event: TicketsClaim): void {
  let lottery = Lottery.load(event.params.lotteryId.toString());
  if (lottery !== null) {
    lottery.claimedTickets = lottery.claimedTickets!.plus(
      event.params.numberTickets
    );
    lottery.save();
  }

  let user = User.load(event.params.claimer.toHex());
  if (user !== null) {
    user.totalLotteryToken = user.totalLotteryToken.plus(
      toBigDecimal(event.params.amount)
    );
    user.save();
  }

  let roundId = concat(
    Bytes.fromHexString(event.params.claimer.toHex()),
    Bytes.fromUTF8(event.params.lotteryId.toString())
  ).toHex();
  let round = Round.load(roundId);
  if (round !== null) {
    round.claimed = true;
    round.save();
  }
}
