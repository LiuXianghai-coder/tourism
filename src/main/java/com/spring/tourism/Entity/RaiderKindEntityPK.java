package com.spring.tourism.Entity;

import javax.persistence.Column;
import javax.persistence.Id;
import java.io.Serializable;
import java.util.Objects;

public class RaiderKindEntityPK implements Serializable {
    private String raiderId;
    private int kindId;

    @Column(name = "raider_id")
    @Id
    public String getRaiderId() {
        return raiderId;
    }

    public void setRaiderId(String raiderId) {
        this.raiderId = raiderId;
    }

    @Column(name = "kind_id")
    @Id
    public int getKindId() {
        return kindId;
    }

    public void setKindId(int kindId) {
        this.kindId = kindId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        RaiderKindEntityPK that = (RaiderKindEntityPK) o;

        if (kindId != that.kindId) return false;
        if (!Objects.equals(raiderId, that.raiderId)) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = raiderId != null ? raiderId.hashCode() : 0;
        result = 31 * result + kindId;
        return result;
    }
}
