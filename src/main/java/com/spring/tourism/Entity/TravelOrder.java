package com.spring.tourism.Entity;

import java.sql.Date;

public class TravelOrder {
    private String userId;

    private String travelId;

    private Double travelPrice;

    private Date bookDate;

    private Date travelDate;

    private String travelTitle;

    private Float travelScore;

    private Integer visitsNum;

    private String imageAddress;

    public String getImageAddress() {
        return imageAddress;
    }

    public void setImageAddress(String imageAddress) {
        this.imageAddress = imageAddress;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getTravelId() {
        return travelId;
    }

    public void setTravelId(String travelId) {
        this.travelId = travelId;
    }

    public Double getTravelPrice() {
        return travelPrice;
    }

    public void setTravelPrice(Double travelPrice) {
        this.travelPrice = travelPrice;
    }

    public Date getBookDate() {
        return bookDate;
    }

    public void setBookDate(Date bookDate) {
        this.bookDate = bookDate;
    }

    public Date getTravelDate() {
        return travelDate;
    }

    public void setTravelDate(Date travelDate) {
        this.travelDate = travelDate;
    }

    public String getTravelTitle() {
        return travelTitle;
    }

    public void setTravelTitle(String travelTitle) {
        this.travelTitle = travelTitle;
    }

    public Float getTravelScore() {
        return travelScore;
    }

    public void setTravelScore(Float travelScore) {
        this.travelScore = travelScore;
    }

    public Integer getVisitsNum() {
        return visitsNum;
    }

    public void setVisitsNum(Integer visitsNum) {
        this.visitsNum = visitsNum;
    }
}
